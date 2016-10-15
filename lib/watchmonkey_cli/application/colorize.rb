module WatchmonkeyCli
  class Application
    module Colorize
      COLORMAP = {
        black: 30,
        red: 31,
        green: 32,
        yellow: 33,
        blue: 34,
        magenta: 35,
        cyan: 36,
        white: 37,
      }

      def colorize str, color = :yellow
        ccode = COLORMAP[color.to_sym] || raise(ArgumentError, "Unknown color #{color}!")
        @opts[:colorize] ? "\e[#{ccode}m#{str}\e[0m" : "#{str}"
      end
      alias_method :c, :colorize
    end
  end
end
