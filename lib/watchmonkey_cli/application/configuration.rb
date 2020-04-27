module WatchmonkeyCli
  class Application
    class Configuration
      module AppHelper
        def wm_cfg_path
          ENV["WM_CFGDIR"].presence || File.expand_path("~/.watchmonkey")
        end

        def config_directory
          "#{wm_cfg_path}/configs"
        end

        def checker_directory
          "#{wm_cfg_path}/checkers"
        end

        def wm_cfg_configfile
          "#{wm_cfg_path}/config.rb"
        end

        def config_filename name = "default"
          "#{config_directory}/#{name}.rb"
        end

        def config_files
          Dir["#{config_directory}/**/*.rb"].reject do |file|
            file.gsub(config_directory, "").split("/").any?{|fp| fp.start_with?("__") }
          end.sort
        end

        def checker_files
          Dir["#{checker_directory}/**/*.rb"].reject do |file|
            file.gsub(config_directory, "").split("/").any?{|fp| fp.start_with?("__") }
          end.sort
        end

        def load_configs!
          configs = config_files
          debug "Loading #{configs.length} config files from `#{config_directory}'"
          configs.each {|f| Configuration.new(self, f) }
        end

        def load_checkers!
          checkers = checker_files
          debug "Loading #{checkers.length} checker files from `#{checker_directory}'"
          checkers.each {|f| require f }
        end

        def load_appconfig
          return unless File.exist?(wm_cfg_configfile)
          eval File.read(wm_cfg_configfile, encoding: "utf-8"), binding, wm_cfg_configfile
        end

        def generate_config name = "default"
          FileUtils.mkdir_p(config_directory)
          File.open(config_filename(name), "w", encoding: "utf-8") do |f|
            f << File.read("#{File.dirname(__FILE__)}/configuration.tpl", encoding: "utf-8")
          end
        end
      end

      def initialize app, file
        @app = app
        @file = file
        @tags = []
        begin
          eval File.read(file, encoding: "utf-8"), binding, file
        rescue
          app.error "Invalid config file #{file}"
          raise
        end
      end

      def ssh_connection name, opts = {}, &b
        @app.fetch_connection(:ssh, name, opts, &b)
      end

      def tag_all! *tags
        @tags = tags.map(&:to_sym)
      end

      def method_missing meth, *args, &block
        if c = @app.checkers[meth.to_s]
          opts = args.extract_options!
          only = @app.opts[:tag_only]
          except = @app.opts[:tag_except]
          tags = (@tags + (opts[:tags] || []).map(&:to_sym)).uniq
          if only.any?
            if tags.any?{|t| only.include?(t) }
              if tags.any?{|t| except.include?(t) }
                return @app.debug "Skipping #{meth} with #{args} and #{opts} due to tag_except filter..."
              end
            else
              return @app.debug "Skipping #{meth} with #{args} and #{opts} due to tag_only filter..."
            end
          elsif tags.any?{|t| except.include?(t) }
            return @app.debug "Skipping #{meth} with #{args} and #{opts} due to tag_except filter..."
          end
          c.enqueue(*args, opts.merge(tags: tags))
        else
          super
        end
      end
    end
  end
end
