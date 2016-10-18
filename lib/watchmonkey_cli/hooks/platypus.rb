module WatchmonkeyCli
  class Platypus
    def self.hook!(app)
      app.instance_eval do
        # =========
        # = Hooks =
        # =========
        hook :result_dump do |robj, args, checker|
          if robj.error?
            robj.messages.each do |m|
              msg  = "#{robj.args[0].try(:name) || robj.args[0].presence || "?"}: #{m}"
              fmsg = msg.gsub('"', '\"').gsub("'", %{'"'"'})
              `osascript -e 'display notification "#{fmsg}" with title "WatchMonkey"'`
            end
          end
        end
      end
    end
  end
end


__END__


log "checking...", false
log "PROGRESS:100", false
$threads.select!(&:alive?)
GC.start
sleep 3
log "sleeping...", false
20.times do |i|
  log "PROGRESS:#{(100-(i*3/60.0*100)).round(0)}", false
  sleep 3
end
