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
        @checkers.each do |key, instance|
          debug "[SETUP] Stopping checker `#{key}' (#{instance.class.name})"
          instance.stop
        end
      end
    end

    # -------------------

    attr_reader :app

    def initialize app
      @app = app
      send(:init) if respond_to?(:init)
    end

    def log msg
      return if app.opts[:quiet]
      _tolog(msg, :info)
      app.sync do
        puts app.c(msg, :blue)
      end
    end

    def debug msg
      return if app.opts[:quiet] || app.opts[:silent]
      _tolog(msg, :debug)
      app.sync do
        puts app.c(msg, :black)
      end
    end

    def error msg
      app.fire(:on_error, msg)
      _tolog(msg, :error)
      app.sync { app.error(msg) }
    end

    def _tolog msg, meth = :log
      return unless app.opts[:logfile]
      app.logger.public_send(meth, msg)
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

    def check! *a
      raise NotImplementedError, "a checker (#{self.class.name}) must implement `#check!' method!"
    end
  end
end
