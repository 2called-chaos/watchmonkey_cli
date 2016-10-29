module WatchmonkeyCli
  class Requeue
    def self.hook!(app)
      app.instance_eval do
        @requeue = []

        # app options
        @opts[:loop_forever] = true
        @opts[:logfile] = logger_filename # enable logging

        # scheduler options
        @opts[:requeue_scheduler_hibernation] = 1 # tickrate of schedule in seconds

        # module options
        @opts[:default_requeue]                   = 60
        # @opts[:default_requeue_ftp_availability]  = 60
        @opts[:default_requeue_mysql_replication] = 30
        @opts[:default_requeue_ssl_expiration]    = 1.hour
        @opts[:default_requeue_unix_defaults]     = false
        # @opts[:default_requeue_unix_df]           = 60
        # @opts[:default_requeue_unix_file_exists]  = 60
        # @opts[:default_requeue_unix_load]         = 60
        @opts[:default_requeue_unix_mdadm]        = 5.minutes
        # @opts[:default_requeue_unix_memory]       = 60
        @opts[:default_requeue_www_availability]  = 30


        # =================
        # = Status thread =
        # =================
        @requeue_status_thread = Thread.new do
          Thread.current.abort_on_exception = true
          while STDIN.gets
            sync do
              puts "==========  STATUS  =========="
              puts "     Queue: #{@queue.length}"
              puts "   Requeue: #{@requeue.length}"
              puts "   Workers: #{@threads.select{|t| t[:working] }.length}/#{@threads.length} working (#{@threads.select(&:alive?).length} alive)"
              puts "   Threads: #{Thread.list.length}"
              # puts "            #{@threads.select(&:alive?).length} alive"
              # puts "            #{@threads.select{|t| t.status == "run" }.length} running"
              # puts "            #{@threads.select{|t| t.status == "sleep" }.length} sleeping"
              puts " Processed: #{@processed}"
              puts "========== //STATUS =========="
            end
          end
        end


        # =================
        # = Scheduler thread =
        # =================
        @requeue_scheduler_thread = Thread.new do
          Thread.current.abort_on_exception = true
          loop do
            break if $wm_runtime_exiting
            sync do
              @requeue.each_with_index do |(run_at, callback), index|
                next if run_at > Time.now
                callback.call()
                @requeue.delete_at(index)
              end
            end
            sleep @opts[:requeue_scheduler_hibernation]
          end
        end


        # =========
        # = Hooks =
        # =========
        hook :dequeue do |checker, args|
          opts = args.extract_options!
          retry_in = opts[:every] if opts[:every].is_a?(Fixnum)
          retry_in = @opts[:"default_requeue_#{checker.class.checker_name}"] if retry_in.nil?
          retry_in = @opts[:default_requeue] if retry_in.nil?
          if retry_in
            debug "Requeuing #{checker} in #{retry_in} seconds"
            requeue checker, args + [opts], retry_in
          end
        end

        hook :wm_shutdown do
          sync do
            @requeue_scheduler_thread.try(:join)
            debug "[ReQ] Clearing #{@requeue.length} items in requeue..."
            @requeue_status_thread.try(:kill).try(:join)
          end
        end


        # ===========
        # = Methods =
        # ===========
        def requeue checker, args, delay = 10
          return if $wm_runtime_exiting
          sync do
            @requeue << [Time.now + delay, ->{
              checker.enqueue(*args)
            }]
          end
        end
      end
    end
  end
end


__END__


log "checking...", false
log "PROGRESS:100", false
$threads.select!(&:alive?)
GC.start
sleep 3
log "sleeping...", false
20.times do |i|
  log "PROGRESS:#{(100-(i*3/60.0*100)).round(0)}", false
  sleep 3
end
