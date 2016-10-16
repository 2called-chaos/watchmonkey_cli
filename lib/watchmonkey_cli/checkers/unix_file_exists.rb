module WatchmonkeyCli
  module Checkers
    class FileExists < Checker
      self.checker_name = "unix_file_exists"

      def enqueue config, host, file, opts = {}
        app.enqueue(self) do
          opts = { message: "File #{file} does not exist!" }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          result = Checker::Result.new(self, host, file, opts)
          debug(result.str_running)
          safe(result.str_safe) { check!(result, host, file, opts) }
          result.dump!
        end
      end

      def check! result, host, file, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{file} | #{opts}]\n\t"
        if host.is_a?(WatchmonkeyCli::LoopbackConnection)
          result.error! "#{descriptor}#{opts[:message]} (ENOENT)" if !File.exist?(file)
        else
          result.command = "test -f #{Shellwords.escape(file)} && echo exists"
          result.result = host.exec(result.command)
          result.error! "#{opts[:message]} (#{result.result.presence || "ENOENT"})" if result.result != "exists"
        end
      end
    end
  end
end
