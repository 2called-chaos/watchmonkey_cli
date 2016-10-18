module WatchmonkeyCli
  class Platypus
    def self.hook!(app, opts = {})
      opts = opts.reverse_merge(notifications: true)
      app.instance_eval do
        # send errors via notification center
        hook :result_dump do |robj, args, checker|
          if robj.error?
            robj.messages.each do |m|
              msg  = "#{robj.args[0].try(:name) || robj.args[0].presence || "?"}: #{m}"

              # makes no sound
              fmsg = msg.gsub('"', '\"').gsub("'", %{'"'"'})
              `osascript -e 'display notification "#{fmsg}" with title "WatchMonkey"'`

              # makes a sound
              # sync { puts "NOTIFICATION:#{msg}" }
            end
          end
        end if opts[:notifications]

        hook :wm_work_start, :wm_work_end do
          # mastermind calculation I swear :D (<-- no idea what I did here)
          # sync { puts "PROGRESS:#{((@threads.length-@threads.select{|t| t[:working] }.length.to_d) / @threads.length * 100).to_i}" }
          sync do
            active = @threads.select{|t| t[:working] }.length
            total  = @threads.select{|t| t[:working] }.length + @queue.length
            perc   = total.zero? ? 100 : (active.to_d / total * 100).to_i
            puts "PROGRESS:#{perc}"
          end
        end
      end
    end
  end
end
