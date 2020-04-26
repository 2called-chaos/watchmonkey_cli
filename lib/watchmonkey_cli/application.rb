module WatchmonkeyCli
  class Application
    attr_reader :opts, :checkers, :connections, :threads, :queue, :hooks, :processed
    include Helper
    include OutputHelper
    include Colorize
    include Core
    include Dispatch
    include Configuration::AppHelper
    include Checker::AppHelper

    # =========
    # = Setup =
    # =========
    def self.dispatch *a
      new(*a) do |app|
        app.load_appconfig
        app.parse_params
        begin
          app.dispatch
          app.haltpoint
        rescue Interrupt
          app.abort("Interrupted", 1)
        ensure
          $wm_runtime_exiting = true
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
        maxrt: 120.seconds,      # max runtime of a single task after which it will be terminated (may break SSH connection), 0/false to not limit runtime
        conclosewait: 10,        # max seconds to wait for connections to be closed (may never if they got killed by maxrt)
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
        opts.on("-d", "--debug [lvl=1]", Integer, "Enable debug output") {|l| @opts[:debug] = l || 1 }
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

    def sync &block
      @monitor.synchronize(&block)
    end

    def dump_and_exit!
      puts "   Queue: #{@queue.length}"
      puts " AppOpts: #{@opts}"
      puts "Checkers: #{@checkers.keys.join(",")}"
      exit 9
    end
  end
end
