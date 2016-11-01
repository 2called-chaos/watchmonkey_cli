module WatchmonkeyCli
  module Checkers
    class FileExists < Checker
      self.checker_name = "unix_file_exists"

      def enqueue host, file, opts = {}
        opts = { message: "File #{file} does not exist!" }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, file, opts)
      end

      def check! result, host, file, opts = {}
        if host.is_a?(WatchmonkeyCli::LoopbackConnection)
          result.error! "#{opts[:message]} (ENOENT)" if !File.exist?(file)
        else
          result.command = "test -f #{Shellwords.escape(file)} && echo exists"
          result.result = host.exec(result.command)
          result.error! "#{opts[:message]} (#{result.result.presence || "ENOENT"})" if result.result != "exists"
        end
      end
    end
  end
end
