module WatchmonkeyCli
  class SshConnection
    attr_reader :opts

    def initialize(id, opts = {}, &initializer)
      @id = id

      if opts.is_a?(String)
        u, h = opts.split("@", 2)
        opts = { user: u, host_name: h }
      elsif opts[:host].is_a?(String)
        u, h = opts[:host].split("@", 2)
        opts = opts.merge(user: u, host_name: h)
        opts.delete(:host)
      end

      # net/ssh options
      @opts = {
        config: false,
      }.merge(opts)
      @mutex = Monitor.new
      initializer.try(:call, @opts)
    end

    def to_s
      "#<WatchmonkeyCli::SshConnection:#{@id}>"
    end

    def name
      "ssh:#{@id}"
    end

    def sync &block
      @mutex.synchronize(&block)
    end

    def exec cmd, chomp = true
      sync do
        res = connection.exec!(cmd)
        chomp ? res.chomp : res
      end
    end

    def connection
      sync { @ssh ||= Net::SSH.start(nil, nil, @opts) }
    end

    def close!
      @ssh.try(:close) rescue false
    end
  end
end
