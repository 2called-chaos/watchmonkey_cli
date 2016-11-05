module WatchmonkeyCli
  module Checkers
    class Ts3License < Checker
      self.checker_name = "ts3_license"

      def enqueue host, file, opts = {}
        opts = { threshold: 1.months }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, file, opts)
      end

      def check! result, host, file, opts = {}
        result.command = "cat #{Shellwords.escape(file)}"
        result.result = host.exec(result.command).force_encoding('UTF-8')

        if result.result.downcase["no such file"]
          result.error! "Failed to read file #{file} (#{result.result})"
        else
          result.data = _parse_response(result.result)
          start_at = zone_parse "UTC", result.data["start date"]
          end_at   = zone_parse "UTC", result.data["end date"]

          if start_at > Time.current
            result.error! "TS3 license is not yet valid (will in #{human_seconds(start_at - Time.current)}, #{start_at})!"
            return
          end

          if end_at <= Time.current
            result.error! "TS3 license is EXPIRED (since #{human_seconds(end_at - Time.current)}, #{end_at})!"
            return
          end

          if end_at <= Time.current + opts[:threshold]
            result.error! "TS3 license is about to expire within threshold (in #{human_seconds(end_at - Time.current)}, #{end_at})!"
            return
          else
            result.info! "TS3 license expires in #{human_seconds(end_at - Time.current)} (#{end_at})!"
          end
        end
      end

      def zone_parse tz, date
        tz_was = Time.zone
        Time.zone = "UTC"
        Time.zone.parse(date)
      ensure
        Time.zone = tz_was
      end

      def _parse_response res
        {}.tap do |r|
          lines = res.split("\n")
          reached_key = false
          lines.each do |l|
            next if l.blank?
            if l[":"]
              c = l.split(":", 2)
              r[c[0].strip] = c[1].strip
            elsif l["==key=="]
              reached_key = true
            elsif reached_key
              r["key"] ||= ""
              r["key"] += l
            end
          end
        end
      end
    end
  end
end
