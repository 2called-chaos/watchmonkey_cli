module WatchmonkeyCli
  module Checkers
    class FtpAvailability < Checker
      self.checker_name = "ftp_availability"

      def enqueue config, host, opts = {}
        app.queue << -> {
          opts = { threshold: 1.months }.merge(opts)
          debug "Running checker #{self.class.checker_name} with [#{host} | #{opts}]"
          safe("[#{self.class.checker_name} | #{host} | #{opts}]\n\t") { check!(host, opts) }
        }
      end

      def check! host, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{opts}]\n\t"
        Net::FTP.open(host) do |ftp|
          ftp.login(opts[:user], opts[:password])
        end
      rescue Net::FTPPermError
        error "#{descriptor}Invalid credentials!"
      rescue SocketError => e
        error "#{descriptor}#{e.class}: #{e.message}"
      end
    end
  end
end
