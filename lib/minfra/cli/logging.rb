# frozen_string_literal: true

module Minfra
  module Cli
    module Logging
      def error(str)
        logger.error(colored(str, :red))
      end

      def exit_error(str)
        error str
        raise Minfra::Cli::Errors::ExitError, str
      end

      def info(str)
        logger.info str
      end

      def warn(str)
        logger.warn(colored(str, :yellow))
      end

      def debug(str)
        logger.debug(str)
      end

      def deprecated(comment)
        logger.warn "DEPRECATED: #{comment}"
      end

      private

      def logger
        Minfra::Cli.logger
      end
      LOGGING_COLORS={ red: '1;31;40', green: '1;32;40' , dark_green: '0;32;40' , yellow: '1;33;40' }
      def colored(str, color)
        if $stdout.isatty
          "\e[#{LOGGING_COLORS[color] || LOGGING_COLORS[:color1]}m#{str}\e[0m"
        else
          str
        end    
      end
    end
  end
end
