# frozen_string_literal: true

require 'thor'
require 'open3'
require 'json'
require 'ostruct'
require 'hiera'

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

require 'active_support'
require 'active_support/core_ext'

require "#{ENV['MINFRA_PATH']}/config/preload.rb" if File.exist?("#{ENV['MINFRA_PATH']}/config/preload.rb")

module Minfra
  module Cli
    extend Minfra::Cli::Logging
    include Minfra::Cli::Hook

    cattr_accessor :logger, :config, :subcommands
    cattr_reader :cli

    def self.init?
      !!@cli
    end

    def self.init(argv = [])
      self.subcommands ||= {}
      @cli = CliStarter.new(argv)
    end

    def self.exec(argv)
      init(argv) unless @cli
      @cli.run
    end

    def self.register(subcommand, info, command)
      self.subcommands[subcommand.to_sym] = OpenStruct.new(name: subcommand, info: info, command: command)
    end

    class CliStarter
      attr_reader :options, :argv, :plugins, :config

      def minfrarc_loaded?
        @minfrarc_loaded
      end

      def minfrarc_me_loaded?
        @minfrarc_me_loaded
      end

      def initialize(argv)
        @argv = argv
        @options = {} # base_path, env, argv_file
        @minfrarc_loaded = false
        @minfrarc_me_loaded = false

        parse_global_options

        @base_path = Pathname.new(@options[:base_path] || ENV['MINFRA_PATH']).expand_path
        @env = @options['-e'] || ENV['MINFRA_ENVIRONMENT'] || 'dev'
        init_config

        init_logger

        @logger.debug("Minfra: loglevel: #{@logger.level}, env: #{@config.orch_env}")

        init_minfrarc
        hiera_init
        init_plugins

        register_subcommands

        @plugins.setup
        require_relative 'cli/main_command'

        setup_subcommands
      end

      def run
        Minfra::Cli::Main.start(@argv)
      end

      private

      def root_path
        Pathname.new(File.expand_path(File.join(__FILE__, '../../../')))
      end

      # will parse -e, --argv_file, --
      def parse_global_options
        @options = {}
        if (idx = @argv.index('-e'))
          @options[:env] = @argv[idx + 1]
          @argv.delete_at(idx)
          @argv.delete_at(idx)
        end

        if (idx = argv.index('--minfra_argv_file'))
          @options[:argv_file] = @argv[idx + 1]
          @argv.delete_at(idx)
          @argv.delete_at(idx)
        end

        if (idx = argv.index('--minfra_path'))
          @options[:base_path] = @argv[idx + 1]
          @argv.delete_at(idx)
          @argv.delete_at(idx)
        end

        @options
      end

      def init_minfrarc
        # load minfrarc for configs
        project_minfrarc_path = @config.base_path.join('config', 'minfrarc.rb')
        if project_minfrarc_path.exist?
          require project_minfrarc_path
          @minfrarc_loaded = true
        end

        # load
        me_minfrarc_path = @config.me_path.join('minfrarc.rb')
        return unless me_minfrarc_path.exist?

        require @me_minfrarc_path
        @minfrarc_me_loaded = true
      end

      def init_plugins
        @plugins = Minfra::Cli::Plugins.load
        @plugins.prepare
      end

      def init_logger
        @logger = Logger.new($stderr)
        @logger.level = ENV['MINFRA_LOGGING_LEVEL'] || @config.project.dig(:minfra, :logging_level) || 'warn'
        Minfra::Cli.logger = @logger
      end

      def init_config
        @config = Config.new(@base_path, @options['-e'] || 'dev')
        Minfra::Cli.config = @config
      end

      def hiera_init
        @hiera_root = @base_path.join('hiera')
        hiera = Hiera.new(config: @hiera_root.join('hiera.yaml').to_s)
        Hiera.logger = :noop
        env_path = config.project.dig(:minfra, :hiera, :env_path) || 'environment'
        
        hiera_main_path = @hiera_root.join("hieradata/#{env_path}/#{@env}.eyaml")
        raise("unknown environment #{@env}, I expect a file at #{hiera_main_path}") unless hiera_main_path.exist?

        scope = { 'minfra_path' => @base_path, 'hieraroot' => @hiera_root.to_s, 'env' => @env }
        special_lookups = hiera.lookup('lookup_options', {}, scope, nil, :priority)

        node_scope = hiera.lookup('env', {}, scope, nil, :deeper)
        scope = scope.merge(node_scope)
        cache = {}
        Kernel.define_method(:l) do |value, default = nil|
          return cache[value] if cache.key?(value)

          values = value.split('.')
          fst_value = values.shift

          lookup_type = if special_lookups[fst_value]
                          { merge_behavior: special_lookups[fst_value]['merge'].to_sym }
                        else
                          :deep
                        end

          result = hiera.lookup(fst_value, default, scope, nil, lookup_type)
          if !values.empty? && result.is_a?(Hash) # we return nil or the scalar value and only drill down on hashes
            result = result.dig(*values)
          end

          result = Hashie::Mash.new(result) if result.is_a?(Hash)
          cache[value] = result
          result
        end
        Kernel.define_method(:l!) do |value, default = nil|
          v = l(value, default)
          raise("Value not found! #{value}") if v.nil?

          v
        end
      end

      def register_subcommands
        # they will call back Minfra::Cli.register
        root_path.join('lib/minfra/cli/commands').each_child do |command_path|
          require command_path if command_path.to_s.match(/\.rb$/) && !command_path.to_s.match(/\#/)
        end
      end

      def setup_subcommands
        Minfra::Cli.subcommands.each_value do |sub|
          Minfra::Cli::Main.desc(sub.name, sub.info)
          Minfra::Cli::Main.subcommand(sub.name, sub.command)
        end
      end
    end
  end
end
