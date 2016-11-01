module WatchmonkeyCli
  module Helper
    BYTE_UNITS = %W(TiB GiB MiB KiB B).freeze

    def human_filesize(s)
      s = s.to_f
      i = BYTE_UNITS.length - 1
      while s > 512 && i > 0
        i -= 1
        s /= 1024
      end
      ((s > 9 || s.modulo(1) < 0.1 ? '%d' : '%.1f') % s) + ' ' + BYTE_UNITS[i]
    end

    def human_number(n)
      n.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
    end

    def human_seconds secs
      secs = secs.to_i
      t_minute = 60
      t_hour = t_minute * 60
      t_day = t_hour * 24
      t_week = t_day * 7
      t_month = t_day * 30
      t_year = t_month * 12
      "".tap do |r|
        if secs >= t_year
          r << "#{secs / t_year}y "
          secs = secs % t_year
        end

        if secs >= t_month
          r << "#{secs / t_month}m "
          secs = secs % t_month
        end

        if secs >= t_week
          r << "#{secs / t_week}w "
          secs = secs % t_week
        end

        if secs >= t_day || !r.blank?
          r << "#{secs / t_day}d "
          secs = secs % t_day
        end

        if secs >= t_hour || !r.blank?
          r << "#{secs / t_hour}h "
          secs = secs % t_hour
        end

        if secs >= t_minute || !r.blank?
          r << "#{secs / t_minute}m "
          secs = secs % t_minute
        end

        r << "#{secs}s" unless r.include?("d")
      end.strip
    end
  end
end
