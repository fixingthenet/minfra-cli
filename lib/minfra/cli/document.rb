# frozen_string_literal: true

module Minfra
  module Cli
    class Document
      def self.document(config, message)
        new(config).document(message)
      end

      def initialize(config)
        @config = config
      end

      def document(_message)
        return true if @config.dev?

        puts 'TBD: calling documentation hooks'
        true
      end
    end
  end
end
