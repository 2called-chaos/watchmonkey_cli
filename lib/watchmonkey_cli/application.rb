module WatchmonkeyCli
  class Application
    attr_reader :opts, :checkers, :connections, :threads, :queue
    include Colorize
    include Dispatch
    include Configuration::AppHelper
    include Checker::AppHelper
    # include Filter
    # include Helpers

    # =========
    # = Setup =
    # =========
    def self.dispatch *a
      new(*a) do |app|
        app.parse_params
        begin
          app.dispatch
        rescue Interrupt
          app.abort("Interrupted", 1)
        end
      end
    end

    def initialize env, argv
      @env, @argv = env, argv
      @connections = {}
      @monitor = Monitor.new
      @threads = []
      @queue = Queue.new
      @opts = {
        dispatch: :index,
        check_for_updates: true,
        colorize: true,
        debug: false,
        threads: 10,
        loop_forever: false,
        silent: false,
        quiet: false,
      }
      init_params
      yield(self)
    end

    def init_params
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: watchmonkey [options]"

        opts.separator(c "# Application options", :blue)
        opts.on("--generate-config [myconfig]", "Generates a example config in ~/.watchmonkey") {|s| @opts[:dispatch] = :generate_config; @opts[:config_name] = s }
        opts.on("-t", "--threads [NUM]", Integer, "Amount of threads to be used for checking (default: 10)") {|s| @opts[:threads] = s }
        opts.on("-s", "--silent", "Only print errors and infos") { @opts[:silent] = true }
        opts.on("-q", "--quiet", "Only print errors") { @opts[:quiet] = true }

        opts.separator("\n" << c("# General options", :blue))
        opts.on("-d", "--debug", "Enable debug output") { @opts[:debug] = true }
        opts.on("-m", "--monochrome", "Don't colorize output") { @opts[:colorize] = false }
        opts.on("-h", "--help", "Shows this help") { @opts[:dispatch] = :help }
        opts.on("-v", "--version", "Shows version and other info") { @opts[:dispatch] = :info }
        opts.on("-z", "Do not check for updates on GitHub (with -v/--version)") { @opts[:check_for_updates] = false }
      end
    end

    def parse_params
      @optparse.parse!(@argv)
    rescue OptionParser::ParseError => e
      abort(e.message)
      dispatch(:help)
      exit 1
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
        @opts[:threads].times do
          @threads << Thread.new do
            Thread.current.abort_on_exception = true
            _queueoff
          end
        end
      else
        _queueoff
      end
    end

    def _queueoff
      while !@queue.empty? || @opts[:loop_forever]
        item = queue.pop(true) rescue false
        item.call()
      end
    end

    def wm_cfg_path
      ENV["WM_CFGDIR"].presence || File.expand_path("~/.watchmonkey")
    end

    # def async &block
    #   @opts[:threads] > 1 ? (@threads << Thread.new(&block)) : block.call
    # end
  end
end
