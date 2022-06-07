module Minfra
  module Cli
    class Document
      def self.document(config, message)
        new(config).document(message)
      end

      def initialize(config)
        @config = config
      end

      def document(message)
        return true if @config.dev?
        puts "TBD: calling documentation hooks"
        true
      end
    end
  end
end
