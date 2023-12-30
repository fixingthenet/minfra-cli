# frozen_string_literal: true

require 'English'
module Minfra
  module Cli
    class Plugins
      def initialize(plugins)
        @plugins = plugins
      end

      def prepare
        @plugins.each(&:prepare)
      end

      def setup
        @plugins.each(&:setup)
      end

      def each(&)
        @plugins.each(&)
      end

      def self.load(base_path)
        found = []
        [base_path.join('config', 'minfra_plugins.json'),
         base_path.join('me', 'minfra_plugins.json')].each do |file|
          next unless File.exist?(file)

          plugins = JSON.parse(File.read(file))
          plugins['plugins'].each do |spec|
            found << Plugin.new(name: spec['name'], opts: spec['opts'] || {}, version: spec['version'],
                                disabled: spec['disabled'])
          end
        end
        new(found)
      end
    end
  end
end
