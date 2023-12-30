# frozen_string_literal: true

require 'thor'
require 'open3'
require 'json'
require 'ostruct'
require 'hiera'

require_relative 'cli/errors'
require_relative 'cli/logging'
require_relative 'cli/templater'

require 'orchparty'
require_relative 'cli/config'
require_relative 'cli/version'
require_relative 'cli/hook'
require_relative 'cli/common'
require_relative 'cli/command'
require_relative 'cli/ask'
require_relative 'cli/document'
require_relative 'cli/runner'
require_relative 'cli/helm_runner'
require_relative 'cli/kubectl_runner'
require_relative 'cli/plugins'
require_relative 'cli/plugin'
require_relative 'cli/cli_starter'

require 'active_support'
require 'active_support/core_ext'

require "#{ENV.fetch('MINFRA_PATH', nil)}/config/preload.rb" if File.exist?("#{ENV.fetch('MINFRA_PATH', nil)}/config/preload.rb")

module Minfra
  module Cli
    extend Minfra::Cli::Logging
    include Minfra::Cli::Hook

    cattr_accessor :logger, :config, :subcommands,:cli

    def self.init?
      !!cli
    end

    def self.init(argv = [])
      self.subcommands ||= {}
      self.cli = CliStarter.new(argv)
    end

    def self.exec(argv)
      init(argv) unless init?
      cli.run
    end

    def self.register(subcommand, info, command)
      self.subcommands[subcommand.to_sym] = OpenStruct.new(name: subcommand, info:, command:)
    end
  end
end
