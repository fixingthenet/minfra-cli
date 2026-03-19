# frozen_string_literal: true

module Minfra
  module Cli
    class Plugin < Command
      desc 'describe', 'describe plugins'
      def describe
        Minfra::Cli.cli.plugins.each do |plugin|
          puts "#{plugin.name} (#{plugin.version})"
        end
      end
      desc 'install', 'install plugins'
      def install
        puts "deprecated, use bundle install"
      end
    end
  end
end
Minfra::Cli.register('plugin', 'dealing wit plugins', Minfra::Cli::Plugin)
