module WatchmonkeyCli
  module Checkers
    class SslExpiration < Checker
      self.checker_name = "ssl_expiration"

      def enqueue page, opts = {}
        opts = { threshold: 28.days, verify: true, timeout: 20 }.merge(opts)
        app.enqueue(self, page, opts)
      end

      def check! result, page, opts = {}
        uri = URI.parse(page)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = opts[:verify] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        http.open_timeout = opts[:timeout]
        http.read_timeout = opts[:timeout]
        cert = nil
        http.start do |h|
          cert = h.peer_cert
        end

        if cert.not_before > Time.current
          result.error! "Certificate is not yet valid (will in #{human_seconds(cert.not_before - Time.current)}, #{cert.not_before})!"
          return
        end

        if cert.not_after <= Time.current
          result.error! "Certificate is EXPIRED (since #{human_seconds(cert.not_after - Time.current)}, #{cert.not_after})!"
          return
        end

        if cert.not_after <= Time.current + opts[:threshold]
          result.error! "Certificate is about to expire within threshold (in #{human_seconds(cert.not_after - Time.current)}, #{cert.not_after})!"
          return
        else
          result.info! "Certificate for `#{page}' expires in #{human_seconds(cert.not_after - Time.current)} (#{cert.not_after})!"
        end
      end
    end
  end
end
