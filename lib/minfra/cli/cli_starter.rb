# frozen_string_literal: true

module Minfra
  module Cli
    class CliStarter
      attr_reader :options, :argv, :plugins, :config, :env_name, :base_path, :logger, :hiera, :envs, :env

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

        @base_path = Pathname.new(@options[:base_path] || ENV.fetch('MINFRA_PATH', nil)).expand_path
        @env_name = @options[:env] || ENV['MINFRA_ENVIRONMENT'] || 'dev'
        init_config

        init_logger

        @logger.debug("Minfra: loglevel: #{@logger.level}, env: #{@config.orch_env}, options: #{@options.inspect}")

        init_minfrarc unless @options[:norc]
        init_envs
        
        init_hiera
        init_plugins

        register_subcommands

        @plugins.setup
        require_relative 'main_command'

        setup_subcommands
      end

      def run
        exit_code = 0
        if @options[:argv_file]
          CSV.foreach(@options[:argv_file]) do |row|
            args = @argv + row
            @logger.debug("Running (#{env_name}): #{args.join(' ')} ")
            begin
              Minfra::Cli::Main.start(args)
            rescue StandardError # esp. Minfra::Cli::Errors::ExitError !
              exit_code = 1
            end
          end
          @logger.debug('Done argv_file loop')
        else
          begin
            Minfra::Cli::Main.start(@argv)
          rescue Minfra::Cli::Errors::ExitError
            exit_code = 1
          end
        end
        exit_code
      end

      def install
        cli = self
        Kernel.define_method(:minfra_cli) do
          cli
        end
        Kernel.define_method(:l) do |key, default = nil|
          minfra_cli.hiera.l(key, default)
        end
        Kernel.define_method(:l!) do |key, default = nil|
          minfra_cli.hiera.l!(key, default)
        end
      end
      private

      def root_path
        Pathname.new(File.expand_path(File.join(__FILE__, '../../../..')))
      end

      # will parse -e, --argv_file, --
      def parse_global_options
        extract_option('-e', :env, 1)
        extract_option('--minfra_argv_file', :argv_file, 1)
        extract_option('--minfra_path', :base_path, 1)
        extract_option('--no-rc', :norc)
      end

      def extract_option(name, sym, arity=0)
        if idx = @argv.index(name)
          if arity == 0
            @options[sym] = true
          else
            @options[sym] = @argv[idx + 1]
            @argv.delete_at(idx)
          end
          @argv.delete_at(idx)
        end
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
        @plugins = Minfra::Cli::Plugins.load(@base_path)
        @plugins.prepare
      end

      def init_logger
        @logger = Logger.new($stderr)
        @logger.level = ENV['MINFRA_LOGGING_LEVEL'] || @config.project.dig(:minfra, :logging_level) || 'warn'
        Minfra::Cli.logger = @logger
      end

      def init_config
        @config = Config.new(@base_path, @env_name || 'dev')
        Minfra::Cli.config = @config
      end

      def init_hiera
        @hiera = @env.hiera 
      end
      
      def init_envs
        @envs={}
        env_path = config.project.dig(:minfra, :hiera, :env_path) || 'environments'
        root = base_path.join('hiera')
        root.join('hieradata',env_path).glob('*.eyaml').sort.each do |path|
          local_env_name = path.basename.sub(/(\..+)/,'').to_s
          @envs[local_env_name]=Env.new(
            hiera_root: root, 
            hiera_env_path: env_path, 
            name: local_env_name, 
            hiera_debug_lookups: ENV['MINFRA_DEBUG_HIERA_LOOKUPS'] == 'true' && env_name == local_env_name, 
            backends: ENV.fetch('MINFRA_HIERA_BACKENDS','').split(',')
          )
        end
        unless @envs[@env_name]
          @logger.error("Environment '#{@env_name}' not found")
          raise Errors::EnvNotFound.new(@env_name) 
        end
        @env = @envs[@env_name] # set the current env
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
