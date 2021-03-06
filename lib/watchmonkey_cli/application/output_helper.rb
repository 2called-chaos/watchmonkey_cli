module WatchmonkeyCli
  class Application
    module OutputHelper
      def puts *a
        sync { @opts[:stdout].send(:puts, *a) }
      end

      def print *a
        sync { @opts[:stdout].send(:print, *a) }
      end

      def warn *a
        sync { @opts[:stdout].send(:warn, *a) }
      end

      def info msg
        puts c("[INFO]  #{msg}", :blue)
      end

      def debug msg, lvl = 1
        puts c("[DEBUG] #{msg}", :black) if @opts[:debug] && @opts[:debug] >= lvl
      end

      def abort msg, exit_code = 1
        puts c("[ABORT] #{msg}", :red)
        exit(exit_code)
      end

      def error msg
        warn c(msg, :red)
      end
    end
  end
end
