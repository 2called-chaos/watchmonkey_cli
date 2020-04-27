# Create this file as ~/.watchmonkey/config.rb
# This file is eval'd in the application object's context after it's initialized!

# Change option defaults (arguments will still override these settings)
# For options refer to application.rb#initialize
#     https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/application.rb
@opts[:threads] = 50



# Integrate ReQueue (module for infinite checking)
# For options refer to the source code:
#     https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/requeue.rb
if @argv.delete("--requeue") || @argv.delete("--reQ")
  require "watchmonkey_cli/hooks/requeue"
  WatchmonkeyCli::Requeue.hook!(self)

  # change options after hooking!
  @opts[:threads] = 8 # don't need as many here because speed is not a concern
  @opts[:default_requeue] = 60 # default delay before requeuing checker, override with `every: 10.minutes` checker option
end



# Integrate Platypus (module for MacOS tool Platypus)
# For options refer to the source code:
#     https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/platypus.rb
if @argv.delete("--platypus")
  require "watchmonkey_cli/hooks/platypus"

  # Options:
  #   * notifications(1)
  #       1 - silent notifications (OS X notifications)
  #       2 - notifications with sound (OS X notifications)
  #       everything else disables notifications (and renders the hook somewhat useless)
  #   * progress(true)
  #       outputs "PROGRESS:##" for Platypus ProgressBar interface (useless if HTML is enabled)
  #   * html(false)
  #       outputs HTML for Platypus WebView interface
  #   * draw_delay(1)
  #       seconds between HTML updates (useless if HTML is disabled)
  WatchmonkeyCli::Platypus.hook!(self, notifications: 1, html: true, draw_delay: 3)

  @opts[:colorize] = false # doesn't render in platypus
end



# Integrate Telegram notifications
# For options refer to the source code:
#     https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/telegram_bot.rb
if @argv.delete("--telegram")
  require "watchmonkey_cli/hooks/telegram_bot"
  WatchmonkeyCli::TelegramBot.hook!(self, {
    # to create a bot refer to https://core.telegram.org/bots#6-botfather
    api_key: "123456789:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",

    # poll timeout, the longer this is (in seconds) the longer it will take to gracefully shut down
    timeout: 5,

    # optionally log incoming messages
    #logger: Logger.new(STDOUT),

    # purge old throttle data, default: 30.days
    #throttle_retention: 30.days,

    # retry sending messages that failed, default: false
    # Not recommended since on connection failure a HUGE amount of messages will accumulate
    # and spam you (and reach rate limits) upon connection restore.
    #retry_on_egress_failure: false,

    # configure your notification targets, if not listed you can't interact with the bot
    notify: [
      [
        # your telegram ID, if you try talking to the bot it will tell you your ID
        987654321,

        # flags
        #   - :all        -- same as :debug, :info, :error (not recommended)
        #   - :debug      -- send all debug messages (not recommended)
        #   - :info       -- send all info messages (not recommended)
        #   - :error      -- send all error messages (RECOMMENDED)
        #   - :admin_flag -- allows access to some commands (/wm_shutdown /stats)
        [:error, :admin_flag],

        # options (all optional, you can comment them out but leave the {})
        {
          # throttle: seconds(int) -- throttle messages by checker uniqid for this long (0/false = no throttle, default)
          throttle: 15*60,

          # only: Array(string, symbol) -- only notify when tagged with given tags
          only: %w[production critical],

          # except: Array(string, symbol) -- don't notify when tagged with given tags (runs after only-check)
          except: %w[database],
        }
      ],
      [123456789, [:error], { throttle: 30.minutes }]
    ],
  })
end
