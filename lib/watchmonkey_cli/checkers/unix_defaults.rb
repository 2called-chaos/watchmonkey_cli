module WatchmonkeyCli
  module Checkers
    class UnixDefaults < Checker
      self.checker_name = "unix_defaults"

      def enqueue config, host, opts = {}
        app.enqueue(self) do
          opts = { unix_load: {}, unix_memory: {}, unix_df: {}, unix_mdadm: {} }.merge(opts)

          # option shortcuts
          opts[:unix_load][:limits] = opts[:load] if opts[:load]
          opts[:unix_load] = false if opts[:load] == false
          opts[:unix_memory][:min_percent] = opts[:memory_min] if opts[:memory_min]
          opts[:unix_memory] = false if opts[:memory_min] == false
          opts[:unix_df][:min_percent] = opts[:df_min] if opts[:df_min]
          opts[:unix_df] = false if opts[:df_min] == false
          opts[:unix_mdadm] = false if opts[:mdadm] == false

          [:unix_load, :unix_memory, :unix_df, :unix_mdadm].each do |which|
            if opts[which] && sec = app.checkers[which.to_s]
              sec.enqueue(config, host, opts[which])
            end
          end
        end
      end

      def check! *args
      end
    end
  end
end
