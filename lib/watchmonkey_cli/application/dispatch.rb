module WatchmonkeyCli
  class Application
    module Dispatch
      def dispatch action = (@opts[:dispatch] || :help)
        if respond_to?("dispatch_#{action}")
          send("dispatch_#{action}")
        else
          abort("unknown action #{action}", 1)
        end
      end

      def dispatch_help
        puts @optparse.to_s
      end

      def dispatch_generate_config
        cfg_name = @opts[:config_name] || "default"
        cfg_file = config_filename(cfg_name)
        puts c("Generating example config `#{cfg_name}'")
        if File.exist?(cfg_file)
          abort "Conflict, file already exists: #{cfg_file}", 1
        else
          generate_config(cfg_name)
          puts c("Writing #{cfg_file}...", :green)
        end
      end

      def dispatch_index
        Thread.abort_on_exception = true
        trap_signals
        init_checkers!
        load_configs!
        dump_and_exit! if @opts[:dump]
        start_checkers!
        @running = true
        spawn_threads_and_run!
        @threads.each(&:join)
        # puts config_directory
        # puts config_files.inspect
      ensure
        @running = false
        stop_checkers!
        close_connections!
        release_signals
      end

      # def dispatch_info
      #   logger.log_without_timestr do
      #     log ""
      #     log "     Your version: #{your_version = Gem::Version.new(Dle::VERSION)}"

      #     # get current version
      #     logger.log_with_print do
      #       log "  Current version: "
      #       if @opts[:check_for_updates]
      #         require "net/http"
      #         log c("checking...", :blue)

      #         begin
      #           current_version = Gem::Version.new Net::HTTP.get_response(URI.parse(Dle::UPDATE_URL)).body.strip

      #           if current_version > your_version
      #             status = c("#{current_version} (consider update)", :red)
      #           elsif current_version < your_version
      #             status = c("#{current_version} (ahead, beta)", :green)
      #           else
      #             status = c("#{current_version} (up2date)", :green)
      #           end
      #         rescue
      #           status = c("failed (#{$!.message})", :red)
      #         end

      #         logger.raw "#{"\b" * 11}#{" " * 11}#{"\b" * 11}", :print # reset cursor
      #         log status
      #       else
      #         log c("check disabled", :red)
      #       end
      #     end
      #     log "  Selected editor: #{c @editor || "none", :magenta}"

      #     # more info
      #     log ""
      #     log "  DLE DirectoryListEdit is brought to you by #{c "bmonkeys.net", :green}"
      #     log "  Contribute @ #{c "github.com/2called-chaos/dle", :cyan}"
      #     log "  Eat bananas every day!"
      #     log ""
      #   end
      # end
    end
  end
end
