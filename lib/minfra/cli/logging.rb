# frozen_string_literal: true

module Minfra
  module Cli
    module Logging
      def error(str)
        logger.error str
      end

      def exit_error(str)
        error str
        exit 1
      end

      def info(str)
        logger.info str
      end

      def warn(str)
        logger.warn str
      end

      def debug(str)
        logger.debug str
      end

      def deprecated(comment)
        logger.warn "DEPRECATED: #{comment}"
      end

      private

      def logger
        Minfra::Cli.logger
      end
    end
  end
end
