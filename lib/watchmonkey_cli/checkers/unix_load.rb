module WatchmonkeyCli
  module Checkers
    class UnixLoad < Checker
      self.checker_name = "unix_load"

      def enqueue config, host, opts = {}
        app.queue << -> {
          opts = { limits: [4, 2, 1.5] }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          result = Checker::Result.new(self, host, opts)
          debug(result.str_running)
          safe(result.str_safe) { check!(result, host, opts) }
          result.dump!
        }
      end

      def check! result, host, opts = {}
        result.command = "uptime"
        result.result = host.exec(result.command)
        ld = result.data = _parse_response(result.result)

        emsg = []
        emsg << "load1 is to high (limit1 is #{opts[:limits][0]}, load1 is #{ld[0]})" if ld[0] > opts[:limits][0]
        emsg << "load5 is to high (limit5 is #{opts[:limits][1]}, load5 is #{ld[1]})" if ld[1] > opts[:limits][1]
        emsg << "load15 is to high (limit15 is #{opts[:limits][2]}, load15 is #{ld[2]})" if ld[2] > opts[:limits][2]
        error!(emsg.join("\n\t")) if emsg.any?
      end

      def _parse_response res
        res.match(/load average(?:s)?: (?:([\d\.]+), ([\d\.]+), ([\d\.]+))|(?:([\d,]+) ([\d\,]+) ([\d\,]+))/i)[1..-1].reject(&:blank?).map{|v| v.gsub(",", ".").to_f }
      end
    end
  end
end
