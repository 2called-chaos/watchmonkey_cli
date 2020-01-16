module WatchmonkeyCli
  module Checkers
    class UnixCpuGovernor < Checker
      self.checker_name = "unix_cpu_governor"

      def enqueue host, opts = {}
        opts = { expect: "performance" }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        qfile = opts[:query_file] || "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        message = opts[:message] || "CPUfreq scaling governor mismatches (expected `#{opts[:expect]}' got `%s')"
        result.command = "cat #{qfile}"
        result.result = host.exec(result.command)
        result.error! message.gsub("%s", result.result) if result.result != opts[:expect]
      end
    end
  end
end
