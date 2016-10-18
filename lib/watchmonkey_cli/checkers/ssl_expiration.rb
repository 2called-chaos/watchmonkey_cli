module WatchmonkeyCli
  module Checkers
    class SslExpiration < Checker
      self.checker_name = "ssl_expiration"

      def enqueue page, opts = {}
        opts = { threshold: 1.months }.merge(opts)
        app.enqueue(self, page, opts)
      end

      def check! result, page, opts = {}
        uri = URI.parse(page)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        cert = nil
        http.start do |h|
          cert = h.peer_cert
        end

        if cert.not_before > Time.current
          result.error! "Certificate is not yet valid (will in #{fseconds(cert.not_before - Time.current)}, #{cert.not_before})!"
          return
        end

        if cert.not_after <= Time.current
          result.error! "Certificate is EXPIRED (since #{fseconds(cert.not_after - Time.current)}, #{cert.not_after})!"
          return
        end

        if cert.not_after <= Time.current + opts[:threshold]
          result.error! "Certificate is about to expire within threshold (in #{fseconds(cert.not_after - Time.current)}, #{cert.not_after})!"
          return
        else
          result.info! "Certificate for `#{page}' expires in #{fseconds(cert.not_after - Time.current)} (#{cert.not_after})!"
        end
      end

      def fseconds secs
        secs = secs.to_i
        t_minute = 60
        t_hour = t_minute * 60
        t_day = t_hour * 24
        t_week = t_day * 7
        t_month = t_day * 30
        t_year = t_month * 12
        "".tap do |r|
          if secs >= t_year
            r << "#{secs / t_year}y "
            secs = secs % t_year
          end

          if secs >= t_month
            r << "#{secs / t_month}m "
            secs = secs % t_month
          end

          if secs >= t_week
            r << "#{secs / t_week}w "
            secs = secs % t_week
          end

          if secs >= t_day || !r.blank?
            r << "#{secs / t_day}d "
            secs = secs % t_day
          end

          if secs >= t_hour || !r.blank?
            r << "#{secs / t_hour}h "
            secs = secs % t_hour
          end

          if secs >= t_minute || !r.blank?
            r << "#{secs / t_minute}m "
            secs = secs % t_minute
          end

          r << "#{secs}s" unless r.include?("d")
        end.strip
      end
    end
  end
end
