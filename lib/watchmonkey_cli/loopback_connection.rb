module WatchmonkeyCli
  class LoopbackConnection
    def initialize(id, opts = {}, &initializer)
      @id = id
      @opts = {}.merge(opts)
      # @mutex = Monitor.new
      initializer.try(:call, @opts)
    end

    def to_s
      "#<WatchmonkeyCli::LoopbackConnection:#{@id}>"
    end

    def sync &block
      # @mutex.synchronize(&block)
      block.try(:call)
    end

    def exec cmd, chomp = true
      _stdin, _stdouterr, _thread = Open3.popen2e(cmd)
      _thread.join
      res = _stdouterr.read
      chomp ? res.chomp : res
    ensure
      _stdin.close rescue false
      _stdouterr.close rescue false
    end

    def close!
    end
  end
end
