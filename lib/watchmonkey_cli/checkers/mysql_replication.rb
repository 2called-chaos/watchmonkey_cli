module WatchmonkeyCli
  module Checkers
    class MysqlReplication < Checker
      self.checker_name = "mysql_replication"

      def enqueue host, opts = {}
        opts = { host: "127.0.0.1", user: "root" }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        cmd = ["mysql"]
        cmd << "-u#{opts[:user]}" if opts[:user]
        cmd << "-p#{opts[:password]}" if opts[:password]
        cmd << "-h#{opts[:host]}" if opts[:host]
        cmd << "-P#{opts[:port]}" if opts[:port]
        cmd << %{-e "SHOW SLAVE STATUS\\G"}
        result.command = cmd.join(" ")
        result.result = host.exec(result.command)
        result.data = _parse_response(result.result)

        io  = result.data["Slave_IO_Running"]
        sql = result.data["Slave_SQL_Running"]
        sbm = result.data["Seconds_Behind_Master"]
        pres = io.nil? && sql.nil? ? "\n\t#{res}" : ""

        if !io && !sql
          result.error! "MySQL replication is offline (IO=#{io},SQL=#{sql})#{pres}"
        elsif !io || !sql
          result.error! "MySQL replication is BROKEN (IO=#{io},SQL=#{sql})#{pres}"
        elsif sbm > 60
          result.error! "MySQL replication is #{sbm} SECONDS BEHIND master (IO=#{io},SQL=#{sql})#{pres}"
        end
      end

      def _parse_response res
        {}.tap do |r|
          res.split("\n").map(&:strip).reject(&:blank?).each do |line|
            next if line.start_with?("***")
            chunks = line.split(":")
            key = chunks.shift.strip
            val = chunks.join(":").strip

            # value cast
            val = false if %w[no No].include?(val)
            val = true if %w[yes Yes].include?(val)
            val = val.to_i if val =~ /^\d+$/

            r[key] = val
          end
        end
      end
    end
  end
end
