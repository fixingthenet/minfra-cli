require 'thor'
require 'open3'
require 'json'
require 'ostruct'
require 'orchparty'

require_relative 'cli/logging'
require_relative 'cli/config'
require_relative 'cli/version'
require_relative 'cli/hook'
require_relative 'cli/common'
require_relative 'cli/command'
require_relative 'cli/templater'
require_relative 'cli/ask'
require_relative 'cli/document'
require_relative 'cli/runner'
require_relative 'cli/plugins'

require 'active_support'
require 'active_support/core_ext'

require "#{ENV['MINFRA_PATH']}/config/preload.rb" if File.exist?("#{ENV['MINFRA_PATH']}/config/preload.rb")

module Minfra
  module Cli
    extend Minfra::Cli::Logging

    def self.root_path
      Pathname.new(File.expand_path(File.join(__FILE__, '../../../')))
    end

    def self.config
      @config ||= Config.new
    end
    def self.scan
      root_path.join("lib/minfra/cli/commands").each_child do |command_path|
        require command_path if command_path.to_s.match(/\.rb$/) && !command_path.to_s.match(/\#/)
      end
      # this is like railties but their called minfracs
      $LOAD_PATH.each do |path|
        minfra_path = Pathname.new(path).join("..","minfracs","init.rb")
        if minfra_path.exist?
          require minfra_path # this should register the command
        end
      end
    end

    def self.register(subcommand,info,command)
      #debug("Registered command #{subcommand}")
      @subcommands ||= {}
      @subcommands[subcommand.to_sym]= OpenStruct.new(name: subcommand, info: info, command: command)
    end

    def self.resolve
      @subcommands.values.each do |sub|
        Minfra::Cli::Main.desc(sub.name,sub.info)
        Minfra::Cli::Main.subcommand(sub.name,sub.command)
      end
    end

    def self.subcommand(name)
      @subcommands[name.to_sym]&.command
    end

    def self.before_hook(subcommand, command, &block)
      subcommand(subcommand).before_hook(command, &block)
    end

    def self.after_hook(subcommand, command, &block)
      subcommand(subcommand).after_hook(command, &block)
    end
  end
end

Minfra::Cli::Plugins.load
Minfra::Cli.scan
require_relative 'cli/main_command'
Minfra::Cli.resolve


