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
