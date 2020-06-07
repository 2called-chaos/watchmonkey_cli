module WatchmonkeyCli
  class Application
    attr_reader :opts, :checkers, :connections, :threads, :queue, :hooks, :processed, :tag_list
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
        rescue SystemExit
          # silence
        ensure
          $wm_runtime_exiting = true
          app.fire(:wm_shutdown)
          if app.filtered_threads.length > 1
            app.error "[WARN] #{app.filtered_threads.length} threads remain (should be 1)..."
            app.filtered_threads.each do |thr|
              app.debug "[THR] #{Thread.main == thr ? "MAIN" : "THREAD"}\t#{thr.alive? ? "ALIVE" : "DEAD"}\t#{thr.inspect}", 10
              thr.backtrace.each do |l|
                app.debug "[THR]\t#{l}", 20
              end
            end
          else
            app.debug "1 thread remains..."
          end
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
      @tag_list = Set.new
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
        autotag: true,           # (internal) if true checkers will get auto tags for checker name and hostname/connection
        silent: false,           # -s flag
        quiet: false,            # -q flag
        stdout: STDOUT,          # (internal) STDOUT redirect
        tag_only: [],            # -o flag
        tag_except: [],          # -e flag
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
        opts.on("-e", "--except tag1,tag2", Array, "Don't run tasks tagged with given tags") {|s| @opts[:tag_except] = s.map(&:to_sym) }
        opts.on("-o", "--only tag1,tag2", Array, "Only run tasks tagged with given tags") {|s| @opts[:tag_only] = s.map(&:to_sym) }
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
      fire(:optparse_init, @optparse)
    end

    def parse_params
      fire(:optparse_parse_before, @optparse)
      fire(:optparse_parse_around, @optparse) do
        @optparse.parse!(@argv)
      end
      fire(:optparse_parse_after, @optparse)
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
