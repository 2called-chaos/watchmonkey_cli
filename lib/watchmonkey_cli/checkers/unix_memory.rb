module WatchmonkeyCli
  module Checkers
    class UnixMemory < Checker
      self.checker_name = "unix_memory"

      def enqueue host, opts = {}
        opts = { min_percent: 25 }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        result.command = "cat /proc/meminfo"
        result.result = host.exec(result.command)
        result.data = _parse_response(result.result)

        if !result.data
          result.error! result.result
        else
          result.error! "memory is low (limit is min. #{opts[:min_percent]}%, got #{result.data["free"]}%)" if opts[:min_percent] && result.data["free"] < opts[:min_percent]
        end
      end

      def _parse_response res
        return false if res.downcase["no such file"]
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
