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
        Minfra::Cli.cli.plugins.each do |plugin|
          puts "setup: #{plugin.name}"
          plugin.install
        end
      end
    end
  end
end
Minfra::Cli.register('plugin', 'dealing wit plugins', Minfra::Cli::Plugin)
