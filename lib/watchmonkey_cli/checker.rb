module WatchmonkeyCli
  class Checker
    # Descendant tracking for inherited classes.
    def self.descendants
      @descendants ||= []
    end

    def self.inherited(descendant)
      descendants << descendant
    end

    def self.checker_name
      @checker_name || self.name
    end

    def self.checker_name= name
      @checker_name = name
    end

    module AppHelper
      def init_checkers!
        @checkers = {}
        WatchmonkeyCli::Checker.descendants.uniq.each do |klass|
          debug "[SETUP] Initializing checker `#{klass.name}'"
          @checkers[klass.checker_name] = klass.new(self)
        end
      end

      def start_checkers!
        @checkers.each do |key, instance|
          debug "[SETUP] Starting checker `#{key}' (#{instance.class.name})"
          instance.start
        end
      end

      def stop_checkers!
        return unless @checkers
        @checkers.each do |key, instance|
          debug "[SETUP] Stopping checker `#{key}' (#{instance.class.name})"
          instance.stop
        end
      end
    end

    class Result
      attr_reader :checker, :type, :args
      attr_accessor :result, :command, :data

      def initialize checker, *args
        @checker = checker
        @args = args
        @mutex = Monitor.new
        @type = :info
        @spool = { error: [], info: [], debug: []}
      end

      def sync &block
        @mutex.synchronize(&block)
      end

      def descriptor
        "[#{@checker.class.checker_name} | #{args.join(" | ")}]"
      end

      def str_safe
        "#{descriptor}\n\t"
      end

      def str_running
        "Running checker #{@checker.class.checker_name} with [#{args.join(" | ")}]"
      end

      def str_descriptor
        "#{descriptor}\n\t"
      end

      def messages
        @spool.map(&:second).flatten
      end

      def dump!
        sync do
          @spool.each do |t, messages|
            while messages.any?
              @checker.send(t, "#{str_descriptor}#{messages.shift}", self)
            end
          end
        end
      end

      [:info, :debug, :error].each do |meth|
        define_method meth do |msg|
          sync { @spool[meth] << msg }
        end
        define_method :"#{meth}!" do |msg = nil|
          sync do
            @spool[meth] << msg if msg
            @type = meth
          end
        end
        define_method :"#{meth}?" do
          sync { @type == meth }
        end
      end
    end

    # -------------------

    include Helper
    attr_reader :app

    def initialize app
      @app = app
      send(:init) if respond_to?(:init)
    end

    def info msg, robj = nil
      app.fire(:on_info, msg, robj)
      return if app.opts[:quiet]
      _tolog(msg, :info)
      app.puts app.c(msg, :blue)
    end

    def debug msg, robj = nil
      app.fire(:on_debug, msg, robj)
      app.fire(:on_message, msg, robj)
      return if app.opts[:quiet] || app.opts[:silent]
      _tolog(msg, :debug)
      app.puts app.c(msg, :black)
    end

    def error msg, robj = nil
      app.fire(:on_error, msg, robj)
      app.fire(:on_message, msg, robj)
      _tolog(msg, :error)
      app.sync { app.error(msg) }
    end

    def _tolog msg, meth = :log
      return unless app.opts[:logfile]
      app.logger.public_send(meth, msg)
    end

    def spawn_sub which, *args
      if sec = app.checkers[which.to_s]
        sec.enqueue(*args)
      end
    end

    # def to_s
    #   string = "#<#{self.class.name}:#{self.object_id} "
    #   fields = self.class.inspector_fields.map{|field| "#{field}: #{self.send(field)}"}
    #   string << fields.join(", ") << ">"
    # end

    def local
      @app.fetch_connection(:loopback, :local)
    end

    def safe descriptor = nil, &block
      tries = 0
      begin
        tries += 1
        block.call
      rescue StandardError => e
        unless tries > 3
          app.sync do
            error "#{descriptor}retry #{tries} reason is `#{e.class}: #{e.message}'"
            e.backtrace.each{|l| debug "\t\t#{l}" }
          end
          sleep 1
          retry
        end
        error "#{descriptor}retries exceeded"
      end
    end

    def rsafe resultobj, &block
      tries = 0
      begin
        tries += 1
        block.call
      rescue StandardError => e
        unless tries > 3
          resultobj.sync do
            resultobj.error! "retry #{tries} reason is `#{e.class}: #{e.message}'"
            e.backtrace.each{|l| resultobj.debug "\t\t#{l}" }
            resultobj.dump!
          end
          sleep 1
          retry
        end
        resultobj.error! "#{descriptor}retries exceeded"
        resultobj.dump!
      end
    end


    # =================
    # =      API      =
    # =================

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

    def enqueue *args
      # Called by configuration defining a check with all the arguments.
      #   e.g. www_availability :my_host, foo: "bar" => args = [:my_host, {foo: "bar"}]
      # Should invoke `app.enqueue` which will by default call `#check!` method with given arguments.
      raise NotImplementedError, "a checker (#{self.class.name}) must implement `#enqueue' method!"
    end

    def check! *a
      # required, see #enqueue
      raise NotImplementedError, "a checker (#{self.class.name}) must implement `#check!' method!"
    end
  end
end
