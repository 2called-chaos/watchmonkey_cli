module WatchmonkeyCli
  class Application
    class Configuration
      module AppHelper
        def config_directory
          "#{wm_cfg_path}/configs"
        end

        def config_files
          Dir["#{config_directory}/**/*.rb"].reject do |file|
            file.gsub(config_directory, "").split("/").any?{|fp| fp.start_with?("__") }
          end
        end

        def config_filename name = "default"
          "#{config_directory}/#{name}.rb"
        end

        def load_configs!
          config_files.each {|f| Configuration.new(self, f) }
        end

        def generate_config name = "default"
          FileUtils.mkdir_p(config_directory)
          File.open(config_filename(name), "w") do |f|
            f << File.read("#{File.dirname(__FILE__)}/configuration.tpl")
          end
        end
      end

      def initialize app, file
        @app = app
        @file = file
        begin
          eval File.read(file), binding, file
        rescue
          app.error "Invalid config file #{file}"
          raise
        end
      end

      def ssh_connection name, opts = {}, &b
        @app.fetch_connection(:ssh, name, opts, &b)
      end

      def method_missing meth, *args, &block
        if c = @app.checkers[meth.to_s]
          c.enqueue(self, *args)
        else
          super
        end
      end
    end
  end
end
