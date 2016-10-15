module WatchmonkeyCli
  module Checkers
    class UnixDf < Checker
      self.checker_name = "unix_df"

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
        res = host.exec("df")
        df = _parse_response(res)

        df.each do |fs|
          error "#{descriptor}disk space on `#{fs[:mountpoint] || "unmounted"}' (#{fs[:filesystem]}) is low (limit is min. #{opts[:min_percent]}%, got #{fs[:free]}%)" if fs[:free] < opts[:min_percent]
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
