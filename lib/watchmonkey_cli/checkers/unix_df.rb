module WatchmonkeyCli
  module Checkers
    class UnixDf < Checker
      self.checker_name = "unix_df"

      def enqueue config, host, opts = {}
        app.enqueue(self) do
          opts = { min_percent: 25 }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          result = Checker::Result.new(self, host, opts)
          debug(result.str_running)
          safe(result.str_safe) { check!(result, host, opts) }
          result.dump!
        end
      end

      def check! result, host, opts = {}
        result.command = "df"
        result.result = host.exec(result.command)
        result.data = _parse_response(result.result)

        result.data.each do |fs|
          result.error! "#{descriptor}disk space on `#{fs[:mountpoint] || "unmounted"}' (#{fs[:filesystem]}) is low (limit is min. #{opts[:min_percent]}%, got #{fs[:free]}%)" if fs[:free] < opts[:min_percent]
        end if opts[:min_percent]
      end

      def _parse_response res
        [].tap do |r|
          res.strip.split("\n")[1..-1].each do |device|
            chunks = device.split(" ")
            r << {
              filesystem: chunks[0],
              size: chunks[1].to_i,
              used: chunks[2].to_i,
              available: chunks[3].to_i,
              use: chunks[4].to_i,
              free: 100-chunks[4].to_i,
              mountpoint: chunks[5],
            }
          end
        end
      end
    end
  end
end
