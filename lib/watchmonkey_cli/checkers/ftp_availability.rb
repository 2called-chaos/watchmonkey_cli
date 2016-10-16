module WatchmonkeyCli
  module Checkers
    class FtpAvailability < Checker
      self.checker_name = "ftp_availability"

      def enqueue config, host, opts = {}
        app.enqueue(self) do
          opts = { threshold: 1.months }.merge(opts)
          result = Checker::Result.new(self, host, opts)
          debug(result.str_running)
          safe(result.str_safe) { check!(result, host, opts) }
          result.dump!
        end
      end

      def check! result, host, opts = {}
        Net::FTP.open(host) do |ftp|
          ftp.login(opts[:user], opts[:password])
        end
      rescue Net::FTPPermError
        result.error "Invalid credentials!"
      rescue SocketError => e
        result.error "#{e.class}: #{e.message}"
      end
    end
  end
end
