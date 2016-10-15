module WatchmonkeyCli
  module Checkers
    class WwwAvailability < Checker
      self.checker_name = "www_availability"

      def enqueue config, page, opts = {}
        app.queue << -> {
          debug "Running checker #{self.class.checker_name} with [#{page} | #{opts}]"
          safe("[#{self.class.checker_name} | #{page} | #{opts}]\n\t") { check!(page, opts) }

          # if available enable ssl_expiration support
          if (sec = app.checkers["ssl_expiration"]) && page.start_with?("https://") && opts[:ssl_expiration] != false
            sec.enqueue(config, page, opts[:ssl_expiration].is_a?(Hash) ? opts.delete(:ssl_expiration) : {})
          end
        }
      end

      def check! page, opts = {}
        descriptor = "[#{self.class.checker_name} | #{page} | #{opts}]\n\t"
        begin
          resp = HTTParty.get(page, no_follow: true, verify: false)
        rescue HTTParty::RedirectionTooDeep => e
          resp = e.response
          original_response = true
        rescue Errno::ECONNREFUSED => e
          error "#{descriptor}Failed to fetch #{page} (#{e.class}: #{e.message})"
          return
        end

        # status
        if opts[:status]
          stati = [*opts[:status]]
          error "#{descriptor}#{resp.code} is not in #{stati}!" if !stati.include?(resp.code.to_i)
        end

        # body
        if rx = opts[:body]
          if rx.is_a?(String)
            error "#{descriptor}body does not include #{rx}!" if !resp.body.include?(rx)
          elsif rx.is_a?(Regexp)
            error "#{descriptor}body does not match #{rx}!" if !resp.body.match(rx)
          end
        end

        # headers
        if opts[:headers]
          hdata = original_response ? resp : resp.headers
          opts[:headers].each do |k, v|
            if !(v.is_a?(Regexp) ? hdata[k].match(v) : hdata[k] == v)
              error "#{descriptor}header #{k} mismatches (expected `#{v}' got `#{hdata[k] || "nil"}')"
            end
          end
        end
      end
    end
  end
end
