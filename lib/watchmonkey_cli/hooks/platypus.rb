module WatchmonkeyCli
  JS_ESCAPE_MAP = { '\\' => '\\\\', '</' => '<\/', "\r\n" => '\n', "\n" => '\n', "\r" => '\n', '"' => '\\"', "'" => "\\'" }
  class Platypus
    class SilentOutput
      def print *a
      end
      def puts *a
      end
      def warn *a
      end
    end

    def self.hook!(app, opts = {})
      opts = opts.reverse_merge(notifications: 1, progress: true, html: false, draw_delay: 1)
      opts[:progress] = false if opts[:html]
      app.instance_eval do
        @opts[:stdout] = SilentOutput.new
        @platypus_status_cache = {
          errors: [],
        }

        # send errors via notification center
        hook :result_dump do |robj, args, checker|
          if robj.error?
            robj.messages.each do |m|
              msg  = "#{robj.args[0].try(:name) || robj.args[0].presence || "?"}: #{m}"
              @platypus_status_cache[:errors].unshift([Time.current, msg])
              @platypus_status_cache[:errors].pop if @platypus_status_cache[:errors].length > 20

              case opts[:notifications]
              when 1
                # makes no sound
                fmsg = msg.gsub('"', '\"').gsub("'", %{'"'"'})
                `osascript -e 'display notification "#{fmsg}" with title "WatchMonkey"'`
              when 2
                # makes a sound
                puts "NOTIFICATION:#{msg}"
              end
            end
          end
        end if opts[:notifications]

        hook :wm_work_start, :wm_work_end do
          # mastermind calculation I swear :D (<-- no idea what I did here)
          # puts "PROGRESS:#{((@threads.length-@threads.select{|t| t[:working] }.length.to_d) / @threads.length * 100).to_i}"
          sync do
            active = @threads.select{|t| t[:working] }.length
            total  = @threads.select{|t| t[:working] }.length + @queue.length
            perc   = total.zero? ? 100 : (active.to_d / total * 100).to_i
            puts "PROGRESS:#{perc}"
          end
        end if opts[:progress]

        # HTML output (fancy as fuck!)
        if opts[:html]
          def escape_javascript str
            str.gsub(/(\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"'])/u) {|match| JS_ESCAPE_MAP[match] }
          end

          def platypus_init_html
            output = %{
              <html>
                <head>
                  <script src="https://code.jquery.com/jquery-3.1.1.min.js"></script>
                  <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
                  <title>Moep</title>
                </head>
                <body style="padding: 8px">
                  <dl class="dl-horizontal">
                    <dt>Items in Queue</dt><dd class="qlength">#{@queue.length}</dd>
                    <dt>Items in ReQ</dt><dd class="rqlength">#{@requeue.length}</dd>
                    <dt>Workers</dt><dd class="workers">#{@threads.select{|t| t[:working] }.length}/#{@threads.length} working (#{@threads.select(&:alive?).length} alive)</dd>
                    <dt>Threads</dt><dd class="tlength">#{Thread.list.length}</dd>
                    <dt>Processed entries</dt><dd class="processed">#{@processed}</dd>
                    <dt>Watching since</dt><dd>#{@boot}</dd>
                    <dt>Last draw</dt><dd class="lastdraw">#{Time.current}</dd>
                  </dl>
                  <h3>Latest errors</h3>
                  <pre class="lasterrors" style="display: block; white-space: pre; word-break: normal; word-wrap: normal;"></pre>
                </body>
              </html>
            }
            sync { Kernel.puts output }
          end

          def platypus_update_html
            dead = @threads.reject(&:alive?).length
            ti = " (#{dead} DEAD)" if dead > 0
            output = %{
              <script>
                $("script").remove();
                $("dd.qlength").html("#{@queue.length}");
                $("dd.rqlength").html("#{@requeue.length}");
                $("dd.workers").html("#{@threads.select{|t| t[:working] }.length}/#{@threads.length} working#{ti}");
                $("dd.tlength").html("#{Thread.list.length}");
                $("dd.processed").html("#{@processed}");
                $("dd.lastdraw").html("#{Time.current}");
                $("pre.lasterrors").html("#{escape_javascript @platypus_status_cache[:errors].map{|t,e| "#{t}: #{e}" }.join("\n")}");
              </script>
            }
            sync { Kernel.puts output }
          end

          platypus_init_html
          @platypus_status_thread = Thread.new do
            Thread.current.abort_on_exception = true
            loop do
              platypus_update_html
              sleep opts[:draw_delay]
            end
          end
          hook :wm_shutdown do
            @platypus_status_thread.try(:kill).try(:join)
          end
        end
      end
    end
  end
end
