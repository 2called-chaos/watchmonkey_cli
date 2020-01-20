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
        load_checkers!
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
        Timeout::timeout(@opts[:conclosewait]) { close_connections! } rescue false
        release_signals
      end

      def dispatch_info
        your_version = Gem::Version.new(WatchmonkeyCli::VERSION)
        puts c ""
        puts c("     Your version: ", :yellow) << c("#{your_version}", :magenta)

        print c("  Current version: ", :yellow)
        if @opts[:check_for_updates]
          require "net/http"
          print c("checking...", :blue)

          begin
            current_version = Gem::Version.new Net::HTTP.get_response(URI.parse(WatchmonkeyCli::UPDATE_URL)).body.strip

            if current_version > your_version
              status = c("#{current_version} (consider update)", :red)
            elsif current_version < your_version
              status = c("#{current_version} (ahead, beta)", :green)
            else
              status = c("#{current_version} (up2date)", :green)
            end
          rescue
            status = c("failed (#{$!.message})", :red)
          end

          print "#{"\b" * 11}#{" " * 11}#{"\b" * 11}" # reset line
          puts status
        else
          puts c("check disabled", :red)
        end

        # more info
        puts c ""
        puts c "  Watchmonkey CLI is brought to you by #{c "bmonkeys.net", :green}"
        puts c "  Contribute @ #{c "github.com/2called-chaos/watchmonkey_cli", :cyan}"
        puts c "  Eat bananas every day!"
        puts c ""
      end
    end
  end
end
