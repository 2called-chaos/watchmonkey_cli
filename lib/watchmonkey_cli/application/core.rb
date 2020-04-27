module WatchmonkeyCli
  class Application
    module Core
      def filtered_threads
        Thread.list.reject do |thr|
          thr.backtrace[0]["gems/concurrent-ruby"] rescue false
        end
      end

      # ===================
      # = Signal trapping =
      # ===================
      def trap_signals
        debug "Trapping INT signal..."
        Signal.trap("INT") do
          $wm_runtime_exiting = true
          Kernel.puts "Interrupting..."
        end
        Signal.trap("TERM") do
          $wm_runtime_exiting = true
          Kernel.puts "Terminating..."
        end
      end

      def release_signals
        debug "Releasing INT signal..."
        Signal.trap("INT", "DEFAULT")
        Signal.trap("TERM", "DEFAULT")
      end

      def haltpoint
        raise Interrupt if $wm_runtime_exiting
      end


      # ==========
      # = Events =
      # ==========
      def hook *which, &hook_block
        which.each do |w|
          @hooks[w.to_sym] ||= []
          @hooks[w.to_sym] << hook_block
        end
      end

      def fire which, *args, &block
        return if @disable_event_firing
        sync { debug "[Event] Firing #{which} (#{@hooks[which].try(:length) || 0} handlers) #{args.map(&:class)}#{" HAS_BLOCK" if block}", 99 }
        if block && (!@hooks[which] || @hooks[which].empty?)
          block.call
        else
          if @hooks[which] && @hooks[which].any?
            if block
              _fire_around(@hooks[which], args, 0, &block)
            else
              @hooks[which].all?{|h| h.call(*args) }
            end
          end
        end
      end

      def _fire_around hooks, args, index = 0, &block
        return block.call unless hook = hooks[index]
        hook.call(*args) { _fire_around(hooks, args, index + 1, &block) }
      end


      # ==========
      # = Logger =
      # ==========
      def logger_filename
        "#{wm_cfg_path}/logs/watchmonkey.log"
      end

      def logger
        sync do
          @logger ||= begin
            FileUtils.mkdir_p(File.dirname(@opts[:logfile]))
            Logger.new(@opts[:logfile], 10, 1024000)
          end
        end
      end


      # =======================
      # = Connection handling =
      # =======================
      def fetch_connection type, id, opts = {}, &initializer
        if !@connections[type] || !@connections[type][id]
          @connections[type] ||= {}
          case type
          when :loopback
            @connections[type][id] = LoopbackConnection.new(id, opts, &initializer)
          when :ssh
            @connections[type][id] = SshConnection.new(id, opts, &initializer)
          else
            raise NotImplementedError, "unknown connection type `#{type}'!"
          end
        end
        @connections[type][id]
      end

      def close_connections!
        @connections.each do |type, clist|
          clist.each do |id, con|
            if con.established?
              debug "[SHUTDOWN] closing #{type} connection #{id} #{con}"
              con.close!
            end
          end
        end
      end


      # =========================
      # = Queue tasks & methods =
      # =========================
      def enqueue checker, *a, &block
        sync do
          cb = block || checker.method(:check!)
          evreg = @disable_event_registration
          fire(:enqueue, checker, a, cb) unless evreg
          @queue << [checker, a, ->(*a) {
            begin
              result = Checker::Result.new(checker, *a)

              # assign tags
              taskopts = a.extract_options!
              result.tags = taskopts[:tags] || []
              a << taskopts

              checker.debug(result.str_running)
              checker.rsafe(result) {
                timeout = checker.class.maxrt.nil? ? @opts[:maxrt] : checker.class.maxrt
                timeout = timeout.call(self, checker, a) if timeout.respond_to?(:call)
                begin
                  if timeout && timeout > 0
                    Timeout::timeout(timeout) { cb.call(result, *a) }
                  else
                    cb.call(result, *a)
                  end
                rescue Timeout::Error => ex
                  result.error! "TIMEOUT: did not finish within #{timeout} seconds, task killed!"
                end
              }
              fire(:result_dump, result, a, checker)
              result.dump!
            ensure
              fire(:dequeue, checker, a) unless evreg
            end
          }]
        end
      end

      def enqueue_sub checker, which, *args
        sync do
          if sec = @checkers[which.to_s]
            begin
              # ef_was = @disable_event_firing
              er_was = @disable_event_registration
              # @disable_event_firing = true
              @disable_event_registration = true
              sec.enqueue(*args)
            ensure
              # @disable_event_firing = ef_was
              @disable_event_registration = er_was
            end
          end
        end
      end

      def spawn_threads_and_run!
        if @opts[:threads] > 1
          debug "Spawning #{@opts[:threads]} consumer threads..."
          @opts[:threads].times do
            @threads << Thread.new do
              Thread.current.abort_on_exception = true
              _queueoff
            end
          end
        else
          debug "Running threadless..."
          _queueoff
        end
      end

      def _queueoff
        while !@queue.empty? || @opts[:loop_forever]
          break if $wm_runtime_exiting
          item = queue.pop(true) rescue false
          if item
            Thread.current[:working] = true
            fire(:wm_work_start, Thread.current)
            sync { @processed += 1 }
            item[2].call(*item[1])
            Thread.current[:working] = false
            fire(:wm_work_end, Thread.current)
          end
          sleep @opts[:loop_wait_empty] if @opts[:loop_forever] && @opts[:loop_wait_empty] && @queue.empty?
        end
      end
    end
  end
end
