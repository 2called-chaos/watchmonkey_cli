module WatchmonkeyCli
  module Checkers
    class FtpAvailability < Checker
      self.checker_name = "ftp_availability"

      def enqueue host, opts = {}
        opts = {}.merge(opts)
        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        Net::FTP.open(host) do |ftp|
          ftp.login(opts[:user], opts[:password])
        end
      rescue Net::FTPPermError
        result.error! "Invalid credentials!"
      rescue SocketError => e
        result.error! "#{e.class}: #{e.message}"
      end
    end
  end
end
