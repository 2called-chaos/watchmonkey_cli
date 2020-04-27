# You will need to place this file somewhere and require it in your
# `~/.watchmonkey/config.rb` in order for it to register in the application.
# You can also place it into `~/watchmonkey/checkers/` and it will get required
# automatically unless the file name starts with two underscores.

module MyWatchmonkeyCheckers
  class MyChecker < WatchmonkeyCli::Checker
    # ============
    # = Required =
    # ============
    # This name defines how you can add tests in your configs.
    #     e.g. my_checker "http://google.com", some_option: true
    self.checker_name = "my_checker"

    # Maximum amount of time this task may run before it gets killed.
    # Set to 0/false to have no time limit whatsoever.
    # Set to proc to evaluate at runtime
    # Defaults to app.opts[:maxrt] if nil/unset
    #self.maxrt = false
    #self.maxrt = 5.minutes
    #self.maxrt = ->(app, checker, args){ app.opts[:maxrt] && app.opts[:maxrt] * 2 }

    # Called by configuration defining a check with all the arguments.
    #   e.g. my_checker "http://google.com", some_option: true
    # Should invoke `app.enqueue` which will by default call `#check!` method with given arguments.
    # Must have options as last argument!
    def enqueue host, opts = {}
      opts = { some_option: false }.merge(opts)

      # If you want to exec commands (locally or SSH) usually a connection or symbol is passed.
      # The buildin handlers follow this logic:
      host = app.fetch_connection(:loopback, :local) if !host || host == :local
      host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)

      # requires first argument to be self (the checker), all other arguments are passed to `#check!` method.
      app.enqueue(self, host, opts)
    end

    # First argument is the result object, all other arguments came from `app.enqueue` call.
    # Must have options as last argument!
    def check! result, host, opts = {}
      # Do your checks and modify the result object.
      # Debug messages will not show if -s/--silent or -q/--quiet argument is passed.
      # Info messages will not show if -q/-quiet argument is passed.

      result.error "foo" # add error message (type won't be changed)
      result.error! "foo" # add error message (type changes to error)
      result.info "foo"
      result.info! "foo"
      result.debug "foo"
      result.debug! "foo"
    end



    # ============
    # = Optional =
    # ============
    def init
      # hook method (called when checker is being initialized)
    end

    def start
      # hook method (called after all checkers were initialized and configs + hosts are loaded)
      # can/should be used for starting connections, etc.
    end

    def stop
      # hook method (called on application shutdown)
      # connections should be closed here

      # DO NOT CLOSE CONNECTIONS HANDLED BY THE APP!
      # Keep in mind that the checkers run concurrently
      # and therefore shared resources might still be in use
    end
  end
end
