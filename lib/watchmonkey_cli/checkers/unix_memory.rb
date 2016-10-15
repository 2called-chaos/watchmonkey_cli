module WatchmonkeyCli
  module Checkers
    class UnixMemory < Checker
      self.checker_name = "unix_memory"

      def enqueue config, host, opts = {}
        app.queue << -> {
          opts = { min_percent: 25 }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          debug "Running checker #{self.class.checker_name} with [#{host} | #{opts}]"
          safe("[#{self.class.checker_name} | #{host} | #{opts}]\n\t") { check!(host, opts) }
        }
      end

      def check! host, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{opts}]\n\t"
        res = host.exec("cat /proc/meminfo")
        md = _parse_response(res)

        if md.is_a?(String)
          error "#{descriptor}#{md}"
        else
          error "#{descriptor}memory is low (limit is min. #{opts[:min_percent]}%, got #{md["free"]}%)" if opts[:min_percent] && md["free"] < opts[:min_percent]
        end
      end

      def _parse_response res
        return res if res.downcase["no such file"]
        {}.tap do |r|
          res.strip.split("\n").each do |line|
            chunks = line.split(":").map(&:strip)
            r[chunks[0]] = chunks[1].to_i
          end
          r["free"] = ((r["MemFree"].to_i + r["Buffers"].to_i + r["Cached"].to_i) / r["MemTotal"].to_f * 100).round(2)
        end
      end
    end
  end
end
