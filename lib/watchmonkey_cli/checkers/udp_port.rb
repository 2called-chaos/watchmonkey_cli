module WatchmonkeyCli
  module Checkers
    class UdpPort < Checker
      self.checker_name = "udp_port"

      def enqueue host, port, opts = {}
        opts = { message: "Port #{port} (UDP) is not reachable!", timeout: 2 }.merge(opts)
        host = app.fetch_connection(:loopback, :local) if !host || host == :local
        host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
        app.enqueue(self, host, port, opts)
      end

      def check! result, host, port, opts = {}
        result.result = port_open?(host.is_a?(String) ? host : host.is_a?(WatchmonkeyCli::LoopbackConnection) ? "127.0.0.1" : host.opts[:host_name] || host.opts[:host] || host.opts[:ip], port, opts)
        result.error! "#{opts[:message]}" unless result.result
      end

      def port_open?(ip, port, opts = {})
        Timeout::timeout(opts[:timeout] ? opts[:timeout] : 3600) do
          s = UDPSocket.new
          s.connect(ip, port)
          s.send "aaa", 0
          s.recv(1)
          s.close
        end
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        return false
      rescue Timeout::Error
        return true
      end
    end
  end
end
