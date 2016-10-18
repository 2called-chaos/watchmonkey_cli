module WatchmonkeyCli
  module Checkers
    class WwwAvailability < Checker
      self.checker_name = "www_availability"

      def enqueue page, opts = {}
        app.enqueue(self, page, opts.except(:ssl_expiration))

        # if available enable ssl_expiration support
        if page.start_with?("https://") && opts[:ssl_expiration] != false && !app.running?
          spawn_sub("ssl_expiration", page, opts[:ssl_expiration].is_a?(Hash) ? opts[:ssl_expiration] : {})
        end
      end

      def check! result, page, opts = {}
        begin
          resp = HTTParty.get(page, no_follow: true, verify: false)
          result.result = resp
        rescue HTTParty::RedirectionTooDeep => e
          result.result = e.response
          original_response = true
        rescue Errno::ECONNREFUSED => e
          result.error! "Failed to fetch #{page} (#{e.class}: #{e.message})"
          return
        end

        # status
        if opts[:status]
          stati = [*opts[:status]]
          result.error! "#{result.result.code} is not in #{stati}!" if !stati.include?(result.result.code.to_i)
        end

        # body
        if rx = opts[:body]
          if rx.is_a?(String)
            result.error! "body does not include #{rx}!" if !result.result.body.include?(rx)
          elsif rx.is_a?(Regexp)
            result.error! "body does not match #{rx}!" if !result.result.body.match(rx)
          end
        end

        # headers
        if opts[:headers]
          hdata = original_response ? result.result : result.result.headers
          opts[:headers].each do |k, v|
            if !(v.is_a?(Regexp) ? hdata[k].match(v) : hdata[k] == v)
              result.error! "header #{k} mismatches (expected `#{v}' got `#{hdata[k] || "nil"}')"
            end
          end
        end
      end
    end
  end
end
