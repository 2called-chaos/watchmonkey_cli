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
    end
  end
end
