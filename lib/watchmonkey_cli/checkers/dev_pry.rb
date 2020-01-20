module WatchmonkeyCli
  module Checkers
    class DevPry < Checker
      self.checker_name = "dev_pry"
      self.maxrt = false

      def enqueue host, opts = {}
      	host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        if app.opts[:threads] > 1
          result.error! "pry only works properly within the main thread, run watchmonkey with `-t0`"
          return
        end

        begin
          require "pry"
          binding.pry
          1+1 # pry may bug out otherwise if it's last statement
        rescue LoadError => ex
          result.error! "pry is required (gem install pry)! #{ex.class}: #{ex.message}"
        end
      end
    end
  end
end
