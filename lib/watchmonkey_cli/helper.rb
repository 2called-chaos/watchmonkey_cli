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
  end
end
