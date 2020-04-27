module WatchmonkeyCli
  class TelegramBot
    BotProbeError = Class.new(::RuntimeError)
    UnknownEgressType = Class.new(::RuntimeError)

    class Event
      attr_reader :app, :bot

      def initialize app, bot, event
        @app, @bot, @event = app, bot, event
      end

      def raw
        @event
      end

      def method_missing method, *args, &block
        @event.__send__(method, *args, &block)
      end

      def user_data
        app.telegram_bot_get_udata(raw.from.id)
      end

      def user_admin?
        user_data && user_data[1].include?(:admin_flag)
      end

      def from_descriptive
        "".tap do |name|
          name << "[BOT] " if from.is_bot
          name << "#{from.first_name} " if from.first_name.present?
          name << "#{from.last_name} " if from.last_name.present?
          name << "(#{from.username}) " if from.username.present?
          name << "[##{from.id}]"
        end.strip
      end

      def message?
        raw.is_a?(Telegram::Bot::Types::Message)
      end

      def message
        return false unless message?
        raw.text.to_s
      end

      def chunks
        @_chunks ||= message.split(" ")
      end

      def command?
        raw.is_a?(Telegram::Bot::Types::Message) && message.start_with?("/")
      end

      def command
        chunks.first if command?
      end

      def args
        chunks[1..-1]
      end

      def reply msg, msgopts = {}
        return unless msg.present?
        msgopts = msgopts.merge(text: msg, chat_id: raw.chat.id)
        msgopts = msgopts.merge(reply_to_message_id: raw.message_id) unless msgopts[:quote] == false
        app.telegram_bot_send(msgopts.except(:quote))
      end
    end

    class BetterQueue
      def initialize
        @stor = []
        @monitor = Monitor.new
      end

      def sync &block
        @monitor.synchronize(&block)
      end

      [:length, :empty?, :push, :pop, :unshift, :shift, :<<].each do |meth|
        define_method(meth) do |*args, &block|
          sync { @stor.send(meth, *args, &block) }
        end
      end
    end

    class PromiseHandler < BetterQueue
      def scrub!
        @stor.dup.each_with_index do |p, i|
          @stor.delete(p) if [:fulfilled, :rejected].include?(p.state)
        end
      end

      def await_all!
        while p = shift
          p.wait
        end
      end
    end

    def self.hook!(app, bot_opts = {})
      app.opts[:telegram_bot] = bot_opts.reverse_merge({
        debug: false,
        info: true,
        error: true,
        throttle_retention: 30.days,
        retry_on_egress_failure: false,
        notify: []
      })

      app.instance_eval do
        hook :dispatch_around do |action, &act|
          throw :skip, true unless action == :index
          begin
            require "telegram/bot"
          rescue LoadError
            abort "[TelegramBot] cannot load telegram/bot, run\n\t# gem install telegram-bot-ruby"
          end
          telegram_bot_dispatch(&act)
        end

        [:debug, :info, :error].each do |level|
          hook :"on_#{level}" do |msg, robj|
            telegram_bot_notify(msg, robj)
          end if app.opts[:telegram_bot][level]
        end

        hook :wm_shutdown do
          debug "[TelegramBot] shutting down telegram bot ingress thread"
          if @telegram_bot_ingress&.alive?
            @telegram_bot_ingress[:stop] = true
            @telegram_bot_ingress.join
          end

          debug "[TelegramBot] shutting down telegram bot egress thread"
          if @telegram_bot_egress&.alive?
            telegram_bot_msg_admins "<b>ALERT: Watchmonkey is shutting down!</b>", parse_mode: "HTML" rescue false
            @telegram_bot_egress_promises.await_all!
            @telegram_bot_egress[:stop] = true
            @telegram_bot_egress.join
          end
        end

        # --------------------

        def telegram_bot_state
          "#{wm_cfg_path}/telegram_bot.wmstate"
        end

        def telegram_bot_dispatch &act
          parent_thread = Thread.current
          @telegram_bot_throttle_locks = {}
          @telegram_bot_egress_promises = PromiseHandler.new
          @telegram_bot_egress_queue = BetterQueue.new
          telegram_bot_throttle # eager load
          telegram_bot_normalize_notify_udata

          # ==================
          # = ingress thread =
          # ==================
          debug "[TelegramBot] Starting telegram bot ingress thread..."
          @telegram_bot_ingress = Thread.new do
            Thread.current.abort_on_exception = true
            begin
              until Thread.current[:stop]
                begin
                  telegram_bot.fetch_updates {|ev| telegram_bot_handle_event(ev) }
                rescue SocketError, Faraday::ConnectionFailed => ex
                  error "[TelegramBot] Poll failure, retrying in 3 seconds (#{ex.class}: #{ex.message})"
                  sleep 3 unless Thread.current[:stop]
                  retry unless Thread.current[:stop]
                end
              end
            rescue StandardError => ex
              parent_thread.raise(ex)
            end
          end

          # wait for telegram bot to be ready
          begin
            Timeout::timeout(10) do
              loop do
                break if @telegram_bot_info
                sleep 0.5
              end
            end
          rescue Timeout::Error
            abort "[TelegramBot] Failed to start telegram bot within 10 seconds, aborting...", 2
          end

          # ==================
          # = egress thread =
          # ==================
          debug "[TelegramBot] Starting telegram bot egress thread..."
          @telegram_bot_egress = Thread.new do
            Thread.current.abort_on_exception = true
            begin
              until Thread.current[:stop] && @telegram_bot_egress_queue.empty?
                begin
                  promise, item = @telegram_bot_egress_queue.shift
                  if item
                    mode = item.delete(:__mode)
                    case mode
                      when :send then promise.set telegram_bot.api.send_message(item)
                      when :edit then promise.set telegram_bot.api.edit_message_text(item)
                      else raise(UnknownEgressType, "Unknown egress mode `#{mode}'!")
                    end
                  else
                    @telegram_bot_egress_promises.scrub!
                    sleep 0.5
                  end
                rescue SocketError, Faraday::ConnectionFailed => ex
                  if opts[:telegram_bot][:retry_on_egress_failure]
                    error "[TelegramBot] Push failure, retrying in 3 seconds (#{ex.class}: #{ex.message})"
                    @telegram_bot_egress_queue.unshift([promise, item.merge(__mode: mode)])
                    sleep 3 unless Thread.current[:stop]
                  else
                    error "[TelegramBot] Push failure, discarding message (#{ex.class}: #{ex.message})"
                    sleep 0.5
                  end
                end
              end
            rescue StandardError => ex
              parent_thread.raise(ex)
            end
          end

          telegram_bot_msg_admins "<b>INFO: Watchmonkey is watching#{" ONCE" unless opts[:loop_forever]}!</b>", disable_notification: true, parse_mode: "HTML"
          act.call
        rescue BotProbeError => ex
          abort ex.message
        ensure
          @telegram_bot_egress_promises.await_all!
          File.open(telegram_bot_state, "w+") do |f|
            f << telegram_bot_throttle.to_json
          end
        end

        def telegram_bot
          @telegram_bot ||= begin
            Telegram::Bot::Client.new(opts[:telegram_bot][:api_key], opts[:telegram_bot].except(:api_key)).tap do |bot|
              begin
                me = bot.api.get_me
                if me["ok"]
                  @telegram_bot_info = me["result"]
                  info "[TelegramBot] Established client [#{@telegram_bot_info["id"]}] #{@telegram_bot_info["first_name"]} (#{@telegram_bot_info["username"]})"
                else
                  raise BotProbeError, "Failed to get telegram client information, got NOK response (#{me.inspect})"
                end
              rescue HTTParty::RedirectionTooDeep, Telegram::Bot::Exceptions::ResponseError => ex
                raise BotProbeError, "Failed to get telegram client information, API key correct? (#{ex.class})"
              rescue SocketError, Faraday::ConnectionFailed => ex
                raise BotProbeError, "Failed to get telegram client information, connection failure? (#{ex.class}: #{ex.message})"
              end
            end
          end
        end

        def telegram_bot_send payload
          Concurrent::Promise.new.tap do |promise|
            @telegram_bot_egress_queue.push([promise, payload.merge(__mode: :send)])
          end
        end

        def telegram_bot_edit payload
          Concurrent::Promise.new.tap do |promise|
            @telegram_bot_egress_queue.push([promise, payload.merge(__mode: :edit)])
          end
        end

        def telegram_bot_tid_exclusive tid, &block
          sync do
            @telegram_bot_throttle_locks[tid] ||= Monitor.new
          end
          @telegram_bot_throttle_locks[tid].synchronize(&block)
        end

        def telegram_bot_throttle
          @telegram_bot_throttle ||= begin
            Hash.new {|h,k| h[k] = Hash.new }.tap do |h|
              if File.exist?(telegram_bot_state)
                json = File.read(telegram_bot_state)
                if json.present?
                  JSON.parse(json).each do |k, v|
                    case k
                    when "__mute_until"
                      h[k] = Time.parse(v)
                    else
                      v.each do |k, data|
                        data[0] = Time.parse(data[0])
                        data[1] = Time.parse(data[1])
                      end
                      v.delete_if {|k, data| data[0] < opts[:telegram_bot][:throttle_retention].ago }
                      h[k.to_i] = v
                    end
                  end
                end
              end
            end
          end
        end

        def telegram_bot_normalize_notify_udata
          opts[:telegram_bot][:notify].each do |a|
            a[1] = (a[1] ? [*a[1]] : [:error]).flat_map(&:to_sym).uniq
            a[2] ||= {}
          end
        end

        def telegram_bot_get_udata lookup_tid
          opts[:telegram_bot][:notify].detect do |tid, level, topts|
            tid == lookup_tid
          end
        end

        def telegram_bot_user_muted? tid, notify = true
          telegram_bot_tid_exclusive(tid) do
            return false unless mute_until = telegram_bot_throttle[tid]["__mute_until"]
            if mute_until > Time.current
              return true
            else
              telegram_bot_throttle[tid].delete("__mute_until")
              telegram_bot_send(text: "You have been unmuted (expired #{mute_until})", chat_id: tid, disable_notification: true) if notify
              return false
            end
          end
        end

        def telegram_bot_notify msg, robj
          to_notify = opts[:telegram_bot][:notify].select do |tid, level, topts|
            level.include?(:all) || level.include?(robj.type)
          end

          to_notify.each do |tid, level, topts|
            telegram_bot_tid_exclusive(tid) do
              next if telegram_bot_user_muted?(tid)
              if robj
                # gate only tags
                next if topts[:only] && topts[:only].any? && !robj.tags.any?{|t| topts[:only].include?(t) }

                # gate except tags
                next if topts[:except] && topts[:except].any? && robj.tags.any?{|t| topts[:except].include?(t) }

                # send message
                throttle = telegram_bot_throttle[tid][robj.uniqid] ||= [Time.current, Time.current, 0, nil]
                throttle[2] += 1
                if (Time.current - throttle[0]) <= (topts[:throttle] || 0) && throttle[3]
                  throttle[1] = Time.current
                  _telegram_bot_sendmsg(tid, msg, throttle[2], throttle, throttle[3])
                else
                  throttle[0] = Time.current
                  throttle[2] = 1
                  throttle[3] = nil
                  _telegram_bot_sendmsg(tid, msg, throttle[2], throttle)
                end
              else
                _telegram_bot_sendmsg(tid, msg, 0, [])
              end
            end
          end
        end

        def _telegram_bot_sendmsg tid, msg, repeat, result_to, msgid = nil
          msg = "<pre>#{ERB::Util.h msg}</pre>"
          msg = "#{msg}\n<b>(message repeated #{repeat} times)</b> #{"    <i>last occurance: #{result_to[1]}</i>" if result_to[1]}" if repeat > 1 && msgid
          (msgid ?
            telegram_bot_edit(chat_id: tid, message_id: msgid, text: msg, disable_web_page_preview: true, parse_mode: "html")
            :
            telegram_bot_send(chat_id: tid, text: msg, disable_web_page_preview: true, parse_mode: "html")
          ).tap do |promise|
            await = Concurrent::Promise.new
            promise.on_success do |m|
              if msgid = m.dig("result", "message_id")
                result_to[3] = msgid
                await.set :success
              else
                puts m.inspect
                await.set :failed
              end
            end
            promise.on_error do |ex|
              error "[TelegramBot] MessagePromiseError - #{ex.class}:#{ex.message}"
              await.set :failed
            end
            @telegram_bot_egress_promises << await
          end
        rescue
        end

        def _telegram_bot_timestr_parse *chunks
          time = Time.current
          chunks.flatten.each do |chunk|
            if chunk.end_with?("d")
              time += chunk[0..-2].to_i.days
            elsif chunk.end_with?("h")
              time += chunk[0..-2].to_i.hours
            elsif chunk.end_with?("m")
              time += chunk[0..-2].to_i.minutes
            elsif chunk.end_with?("s")
              time += chunk[0..-2].to_i.seconds
            else
              time += chunk.to_i.seconds
            end
          end
          time
        end

        def telegram_bot_handle_event ev
          Event.new(self, telegram_bot, ev).tap do |event|
            begin
              ctrl = catch :event_control do
                case event.command
                when "/ping"
                  event.reply "Pong!"
                  throw :event_control, :done
                when "/start"
                  if event.user_data
                    event.reply [].tap{|m|
                      m << "<b>Welcome!</b> I will tell you if something is wrong with your infrastructure."
                      m << "Your current tags are: #{event.user_data[1].join(", ")}"
                      m << "<b>You have admin permissions!</b>" if event.user_admin?
                      m << "\nInstead of muting me in Telegram you can silence me for a while with <code>/mute 6h 30m</code>."
                      m << "Use <code>/help</code> for more information."
                    }.join("\n"), parse_mode: "HTML"
                  else
                    event.reply %{
                      Hello there, unfortunately I don't recognize your user id (#{event.from.id}).
                      Please ask your admin to add you to the configuration file.
                    }
                  end
                  throw :event_control, :done
                when "/mute"
                  if event.user_data
                    telegram_bot_tid_exclusive(event.from.id) do
                      telegram_bot_user_muted?(event.from.id) # clears if expired
                      if event.args.any?
                        mute_until = _telegram_bot_timestr_parse(event.args)
                        telegram_bot_throttle[event.from.id]["__mute_until"] = mute_until
                        event.reply "You are muted until #{mute_until}\nUse /unmute to prematurely cancel the mute.", disable_notification: true
                      else
                        msg = "Usage: <code>/mute &lt;1d 2h 3m 4s&gt;</code>"
                        if mute_until = telegram_bot_throttle[event.from.id]["__mute_until"]
                          msg << "\n<b>You are currently muted until #{mute_until}</b> /unmute"
                        end
                        event.reply msg, parse_mode: "HTML", disable_notification: true
                      end
                    end
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                when "/unmute"
                  if event.user_data
                    telegram_bot_tid_exclusive(event.from.id) do
                      if mute_until = telegram_bot_throttle[event.from.id]["__mute_until"]
                        event.reply "You have been unmuted (prematurely canceled #{mute_until})", disable_notification: true
                      else
                        event.reply "You are not currently muted.", disable_notification: true
                      end
                    end
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                when "/scan", "/rescan"
                  if event.user_data
                    if respond_to?(:requeue_runall)
                      event.reply "Triggering all tasks in ReQueue…", disable_notification: true
                      requeue_runall
                    else
                      event.reply "Watchmonkey is not running with ReQueue!", disable_notification: true
                    end
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                when "/clearthrottle", "/clearthrottles"
                  if event.user_data
                    telegram_bot_tid_exclusive(event.from.id) do
                      was_muted = telegram_bot_throttle[event.from.id].delete("__mute_until")
                      telegram_bot_throttle.delete(event.from.id)
                      event.reply "Cleared all your throttles!", disable_notification: true
                      if was_muted
                        telegram_bot_throttle[event.from.id]["__mute_until"] = was_muted
                      end
                    end
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                when "/status"
                  if event.user_admin?
                    msg = []
                    msg << "<pre>"
                    msg << "==========  STATUS  =========="
                    msg << "     Queue: #{@queue.length}"
                    msg << "   Requeue: #{@requeue.length}" if @requeue
                    msg << "   Workers: #{@threads.select{|t| t[:working] }.length}/#{@threads.length} working (#{@threads.select(&:alive?).length} alive)"
                    msg << "   Threads: #{filtered_threads.length}"
                    msg << " Processed: #{@processed}"
                    msg << "  Promises: #{@telegram_bot_egress_promises.length}"
                    msg << "========== //STATUS =========="
                    msg << "</pre>"
                    event.reply msg.join("\n"), parse_mode: "HTML", disable_notification: true
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                when "/help"
                  event.reply [].tap{|m|
                    m << "<b>/start</b> Bot API"
                    if event.user_data
                      m << "<b>/mute &lt;time&gt;</b> Don't send messages for this long (e.g. <code>/mute 1d 2h 3m 4s</code>)"
                      m << "<b>/unmute</b> Cancel mute"
                      m << "<b>/scan</b> Trigger all queued scans in ReQueue"
                      m << "<b>/clearthrottle</b> Clears your throttled messages"
                    end
                    if event.user_admin?
                      m << "<b>/status</b> Some status information"
                      m << "<b>/wm_shutdown</b> Shutdown watchmonkey process, may respawn if deamonized"
                    end
                  }.join("\n"), parse_mode: "HTML", disable_notification: true
                  throw :event_control, :done
                when "/wm_shutdown"
                  if event.user_admin?
                    $wm_runtime_exiting = true
                    telegram_bot_msg_admins "ALERT: `#{event.from_descriptive}` invoked shutdown!"
                    throw :event_control, :done
                  else
                    throw :event_control, :access_denied
                  end
                end
              end

              if ctrl == :access_denied
                event.reply("You don't have sufficient permissions to execute this command!")
              elsif ctrl == :bad_request
                event.reply("Bad Request: Your input is invalid!")
              end
            rescue StandardError => ex
              event.reply("Sorry, encountered an error while processing your request!")

              # notify admins
              msg = "ERROR: Encountered error while processing a request!\n"
              msg << "Request: #{ERB::Util.h event.message}\n"
              msg << "Origin: #{ERB::Util.h event.from.inspect}\n"
              msg << "<pre>#{ERB::Util.h ex.class}: #{ERB::Util.h ex.message}\n#{ERB::Util.h ex.backtrace.join("\n")}</pre>"
              telegram_bot_msg_admins(msg, parse_mode: "HTML")
            end
          end
        end

        def telegram_bot_msg_admins msg, msgopts = {}
          return unless msg.present?
          opts[:telegram_bot][:notify].each do |tid, level, topts|
            next unless level.include?(:admin_flag)
            next if telegram_bot_user_muted?(tid)
            telegram_bot_send(msgopts.merge(text: msg, chat_id: tid))
          end
        end
      end
    end
  end
end
