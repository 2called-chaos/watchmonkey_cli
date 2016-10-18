module WatchmonkeyCli
  class Application
    attr_reader :opts, :checkers, :connections, :threads, :queue, :hooks, :processed
    include Helpers
    include Colorize
    include Dispatch
    include Configuration::AppHelper
    include Checker::AppHelper

    # =========
    # = Setup =
    # =========
    def self.dispatch *a
      new(*a) do |app|
        app.load_config
        app.parse_params
        begin
          app.dispatch
          app.haltpoint
        rescue Interrupt
          app.abort("Interrupted", 1)
        ensure
          app.fire(:wm_shutdown)
          app.debug "#{Thread.list.length} threads remain..."
        end
      end
    end

    def initialize env, argv
      @boot = Time.current
      @env, @argv = env, argv
      @connections = {}
      @hooks = {}
      @monitor = Monitor.new
      @threads = []
      @queue = Queue.new
      @processed = 0
      @running = false
      @opts = {
        dump: false,             # (internal) if true app will dump itself and exit before running any checks
        dispatch: :index,        # (internal) action to dispatch
        check_for_updates: true, # -z flag
        colorize: true,          # -m flag
        debug: false,            # -d flag
        threads: 10,             # -t flag
        loop_forever: false,     # (internal) loop forever (app mode)
        loop_wait_empty: 1,      # (internal) time to wait in thread if queue is empty
        silent: false,           # -s flag
        quiet: false,            # -q flag
        stdout: STDOUT,          # (internal) STDOUT redirect
      }
      init_params
      yield(self)
    end

    def init_params
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: watchmonkey [options]"

        opts.separator(c "# Application options", :blue)
        opts.on("--generate-config [myconfig]", "Generates a example config in ~/.watchmonkey") {|s| @opts[:dispatch] = :generate_config; @opts[:config_name] = s }
        opts.on("-l", "--log [file]", "Log to file, defaults to ~/.watchmonkey/logs/watchmonkey.log") {|s| @opts[:logfile] = s || logger_filename }
        opts.on("-t", "--threads [NUM]", Integer, "Amount of threads to be used for checking (default: 10)") {|s| @opts[:threads] = s }
        opts.on("-s", "--silent", "Only print errors and infos") { @opts[:silent] = true }
        opts.on("-q", "--quiet", "Only print errors") { @opts[:quiet] = true }

        opts.separator("\n" << c("# General options", :blue))
        opts.on("-d", "--debug", "Enable debug output") { @opts[:debug] = true }
        opts.on("-m", "--monochrome", "Don't colorize output") { @opts[:colorize] = false }
        opts.on("-h", "--help", "Shows this help") { @opts[:dispatch] = :help }
        opts.on("-v", "--version", "Shows version and other info") { @opts[:dispatch] = :info }
        opts.on("-z", "Do not check for updates on GitHub (with -v/--version)") { @opts[:check_for_updates] = false }
        opts.on("--dump-core", "for developers") { @opts[:dump] = true }
      end
    end

    def parse_params
      @optparse.parse!(@argv)
    rescue OptionParser::ParseError => e
      abort(e.message)
      dispatch(:help)
      exit 1
    end

    def running?
      @running
    end

    def load_config
      return unless File.exist?(wm_cfg_configfile)
      eval File.read(wm_cfg_configfile, encoding: "utf-8"), binding, wm_cfg_configfile
    end

    def puts *a
      sync { @opts[:stdout].send(:puts, *a) }
    end

    def print *a
      sync { @opts[:stdout].send(:print, *a) }
    end

    def warn *a
      sync { @opts[:stdout].send(:warn, *a) }
    end

    def debug msg
      puts c("[DEBUG] #{msg}", :black) if @opts[:debug]
    end

    def abort msg, exit_code = 1
      puts c("[ABORT] #{msg}", :red)
      exit(exit_code)
    end

    def error msg
      warn c(msg, :red)
    end

    def hook *which, &hook_block
      which.each do |w|
        @hooks[w.to_sym] ||= []
        @hooks[w.to_sym] << hook_block
      end
    end

    def fire which, *args
      return if @disable_event_firing
      sync { debug "[Event] Firing #{which} (#{@hooks[which].try(:length) || 0} handlers) #{args.map(&:class)}" }
      @hooks[which] && @hooks[which].each{|h| h.call(*args) }
    end

    def fetch_connection type, id, opts = {}, &initializer
      if !@connections[type] || !@connections[type][id]
        @connections[type] ||= {}
        case type
        when :loopback
          @connections[type][id] = LoopbackConnection.new(id, opts, &initializer)
        when :ssh
          @connections[type][id] = SshConnection.new(id, opts, &initializer)
        else
          raise NotImplementedError, "unknown connection type `#{type}'!"
        end
      end
      @connections[type][id]
    end

    def close_connections!
      @connections.each do |type, clist|
        clist.each{|id, con| con.close! }
      end
    end

    def sync &block
      @monitor.synchronize(&block)
    end

    def spawn_threads_and_run!
      if @opts[:threads] > 1
        debug "Spawning #{@opts[:threads]} consumer threads..."
        @opts[:threads].times do
          @threads << Thread.new do
            Thread.current.abort_on_exception = true
            _queueoff
          end
        end
      else
        debug "Running threadless..."
        _queueoff
      end
    end

    def enqueue checker, *a, &block
      sync do
        cb = block || checker.method(:check!)
        evreg = @disable_event_registration
        fire(:enqueue, checker, a, cb) unless evreg
        @queue << [checker, a, ->(*a) {
          begin
            result = Checker::Result.new(checker, *a)
            checker.debug(result.str_running)
            checker.safe(result.str_safe) { cb.call(result, *a) }
            fire(:result_dump, result, a, checker)
            result.dump!
          ensure
            fire(:dequeue, checker, a) unless evreg
          end
        }]
      end
    end

    def enqueue_sub checker, which, *args
      sync do
        if sec = @checkers[which.to_s]
          begin
            # ef_was = @disable_event_firing
            er_was = @disable_event_registration
            # @disable_event_firing = true
            @disable_event_registration = true
            sec.enqueue(*args)
          ensure
            # @disable_event_firing = ef_was
            @disable_event_registration = er_was
          end
        end
      end
    end

    def _queueoff
      while !@queue.empty? || @opts[:loop_forever]
        break if $wm_runtime_exiting
        item = queue.pop(true) rescue false
        if item
          Thread.current[:working] = true
          fire(:wm_work_start, Thread.current)
          sync { @processed += 1 }
          item[2].call(*item[1])
          Thread.current[:working] = false
          fire(:wm_work_end, Thread.current)
        end
        sleep @opts[:loop_wait_empty] if @opts[:loop_forever] && @opts[:loop_wait_empty] && @queue.empty?
      end
    end

    def wm_cfg_path
      ENV["WM_CFGDIR"].presence || File.expand_path("~/.watchmonkey")
    end

    def wm_cfg_configfile
      "#{wm_cfg_path}/config.rb"
    end

    def logger_filename
      "#{wm_cfg_path}/logs/watchmonkey.log"
    end

    def logger
      sync do
        @logger ||= begin
          FileUtils.mkdir_p(File.dirname(@opts[:logfile]))
          Logger.new(@opts[:logfile], 10, 1024000)
        end
      end
    end

    def trap_signals
      debug "Trapping INT signal..."
      Signal.trap("INT") do
        $wm_runtime_exiting = true
        Kernel.puts "Interrupting..."
      end
    end

    def release_signals
      debug "Releasing INT signal..."
      Signal.trap("INT", "DEFAULT")
    end

    def haltpoint
      raise Interrupt if $wm_runtime_exiting
    end

    def dump_and_exit!
      puts "   Queue: #{@queue.length}"
      puts " AppOpts: #{@opts}"
      puts "Checkers: #{@checkers.keys.join(",")}"
      exit 9
    end
  end
end
