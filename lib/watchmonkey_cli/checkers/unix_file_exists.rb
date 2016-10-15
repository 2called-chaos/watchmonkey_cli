module WatchmonkeyCli
  module Checkers
    class FileExists < Checker
      self.checker_name = "unix_file_exists"

      def enqueue config, host, file, opts = {}
        app.queue << -> {
          opts = { message: "File #{file} does not exist!" }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          debug "Running checker #{self.class.checker_name} with [#{host} | #{file} | #{opts}]"
          safe("[#{self.class.checker_name} | #{host} | #{file} | #{opts}]\n\t") { check!(host, file, opts) }
        }
      end

      def check! host, file, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{file} | #{opts}]\n\t"
        if host.is_a?(WatchmonkeyCli::LoopbackConnection)
          error "#{descriptor}#{opts[:message]} (ENOENT)" if !File.exist?(file)
        else
          res = host.exec %{test -f #{Shellwords.escape(file)} && echo exists}
          error "#{descriptor}#{opts[:message]} (#{res.presence || "ENOENT"})" if res != "exists"
        end
      end
    end
  end
end
