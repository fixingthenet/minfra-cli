# frozen_string_literal: true

require 'English'
module Minfra
  module Cli
    class Plugins
      def initialize(plugins)
        @plugins = plugins
      end

      def setup
        @plugins.each(&:setup)
      end

      def each(&)
        @plugins.each(&)
      end

      def self.load
        found = []
        definition = Bundler.definition.specs.each do |spec|
           found << Plugin.new(spec) if Pathname.new(spec.full_gem_path).join('minfracs').exist?
        end
        new(found)
      end
    end
  end
end
