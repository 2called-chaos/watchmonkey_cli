module WatchmonkeyCli
  module Checkers
    class UnixMdadm < Checker
      self.checker_name = "unix_mdadm"

      def enqueue config, host, opts = {}
        app.queue << -> {
          opts = { log_checking: true }.merge(opts)
          host = app.fetch_connection(:loopback, :local) if !host || host == :local
          host = app.fetch_connection(:ssh, host) if host.is_a?(Symbol)
          debug "Running checker #{self.class.checker_name} with [#{host} | #{opts}]"
          safe("[#{self.class.checker_name} | #{host} | #{opts}]\n\t") { check!(host, opts) }
        }
      end

      def check! host, opts = {}
        descriptor = "[#{self.class.checker_name} | #{host} | #{opts}]\n\t"
        res = host.exec("cat /proc/mdstat")
        md = _parse_response(res)

        if md.is_a?(String)
          error "#{descriptor}#{md}"
        else
          md[:devices].each do |rdev|
            dev = rdev[0].split(" ").first
            status = rdev[1].split(" ").last
            progress = rdev[2].to_s
            return if status == "chunks"
            error "#{dev} seems broken (expected U+, got `#{status}')" if status !~ /\[U+\]/
            if opts[:log_checking] && progress && m = progress.match(/\[[=>\.]+\]\s+([^\s]+)\s+=\s+([^\s]+)\s+\(([^\/]+)\/([^\)]+)\)\s+finish=([^\s]+)\s+speed=([^\s]+)/i)
              log "#{dev} on is checking (status:#{m[1]}|done:#{m[2]}|eta:#{m[5]}|speed:#{m[6]}|blocks_done:#{m[3]}/#{m[4]})"
            end
          end
        end
      end

      def _parse_response res
        return res if res.downcase["no such file"]

        { devices: [] }.tap do |r|
          res = res.strip
          chunks = res.split("\n").map(&:strip)
          chunks.reject!{|el| el =~ /\Awarning:/i }

          # personalities
          personalities = chunks.delete_at(chunks.index{|c| c =~ /^personalities/i })
          r[:personalities] = personalities.match(/^personalities(?:\s?): (.*)$/i)[1].split(" ").map{|s| s[1..-2] }

          # unusued devices
          unused_devices = chunks.delete_at(chunks.index{|c| c =~ /^unused devices/i })
          r[:unused_devices] = unused_devices.match(/^unused devices\s?: (.*)$/i)[1]

          # device output
          chunks.join("\n").split("\n\n").map{|sp| sp.split("\n") }.each do |rdev|
            r[:devices] << rdev
          end
        end
      rescue StandardError => e
        return "failed to parse mdadm output - #{e.class}: #{e.message}"
      end
    end
  end
end
