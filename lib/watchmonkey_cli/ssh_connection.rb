module WatchmonkeyCli
  class SshConnection
    def initialize(id, opts = {}, &initializer)
      @id = id
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
      @ssh.try(:close) #rescue false
    end
  end
end
