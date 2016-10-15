module WatchmonkeyCli
  module Checkers
    class UnixLoad < Checker
      self.checker_name = "unix_load"

      def enqueue config, host, opts = {}
        app.queue << -> {
          opts = { limits: [4, 2, 1.5] }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          debug "Running checker #{self.class.checker_name} with [#{host} | #{opts}]"
          safe("[#{self.class.checker_name} | #{host} | #{opts}]\n\t") { check!(host, opts) }
        }
      end

      def check! host, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{opts}]"
        res = host.exec("uptime")
        ld = _parse_response(res)

        descriptor += "\n\tload1 is to high (limit1 is #{opts[:limits][0]}, load1 is #{ld[0]})" if ld[0] > opts[:limits][0]
        descriptor += "\n\tload5 is to high (limit5 is #{opts[:limits][1]}, load5 is #{ld[1]})" if ld[1] > opts[:limits][1]
        descriptor += "\n\tload15 is to high (limit15 is #{opts[:limits][2]}, load15 is #{ld[2]})" if ld[2] > opts[:limits][2]
        error(descriptor) if descriptor["\n"]
      end

      def _parse_response res
        res.match(/load average(?:s)?: (?:([\d\.]+), ([\d\.]+), ([\d\.]+))|(?:([\d,]+) ([\d\,]+) ([\d\,]+))/i)[1..-1].reject(&:blank?).map{|v| v.gsub(",", ".").to_f }
      end
    end
  end
end
