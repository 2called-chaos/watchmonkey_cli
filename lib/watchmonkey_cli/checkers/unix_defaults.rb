module WatchmonkeyCli
  module Checkers
    class UnixDefaults < Checker
      self.checker_name = "unix_defaults"

      def enqueue host, opts = {}
        opts = { unix_load: {}, unix_memory: {}, unix_df: {}, unix_mdadm: {} }.merge(opts)

        # option shortcuts
        opts[:unix_load][:limits] = opts[:load] if opts[:load]
        opts[:unix_load] = false if opts[:load] == false
        opts[:unix_memory][:min_percent] = opts[:memory_min] if opts[:memory_min]
        opts[:unix_memory] = false if opts[:memory_min] == false
        opts[:unix_df][:min_percent] = opts[:df_min] if opts[:df_min]
        opts[:unix_df] = false if opts[:df_min] == false
        opts[:unix_mdadm] = false if opts[:mdadm] == false
        opts.delete(:load)
        opts.delete(:memory_min)
        opts.delete(:df_min)
        opts.delete(:mdadm)

        app.enqueue(self, host, opts)
      end

      def check! result, host, opts = {}
        [:unix_load, :unix_memory, :unix_df, :unix_mdadm].each do |which|
          app.enqueue_sub(self, which, host, opts[which]) if opts[which]
        end
      end
    end
  end
end
