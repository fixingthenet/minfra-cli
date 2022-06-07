module Minfra
  module Cli
    module Logging
      def error(str)
        STDERR.puts "Error: #{str}"
      end

      def exit_error(str)
        error str
        exit 1
      end

      def info(str)
        STDOUT.puts str
      end

      def debug(str)
        STDOUT.puts "Debug: #{str}"
      end

      def deprecated(comment)
        puts "DEPRECATED: #{comment}"
      end
    end
  end
end
