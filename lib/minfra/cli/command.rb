# frozen_string_literal: true

module Minfra
  module Cli
    class Command < Thor
      include Common
      include Logging

      private

      def minfra_config
        Minfra::Cli.config
      end
    end
  end
end
