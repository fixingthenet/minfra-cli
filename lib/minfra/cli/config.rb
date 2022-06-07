require 'pathname'
require 'hashie/mash'
require 'json'
require_relative 'templater'
module Minfra
  module Cli
    # responsible the read the config file(s) and add a small abstraction layer on top of it
    class Config
      include Logging
      
      class ConfigNotFoundError < StandardError
      end
      class EnvironmentNotFoundError < StandardError
      end

      attr_reader :base_path
      attr_reader :config_path
      attr_reader :stacks_path
      attr_reader :me_path
      attr_reader :kube_path
      attr_reader :kube_config_path
      attr_reader :kind_config_path

      attr_reader :orch_env
      attr_reader :orch_env_config
      attr_reader :config
      attr_reader :project

      def self.load(orch_env, base_path_str = nil)
        new(base_path_str).load(orch_env)
      end

      def initialize(base_path_str=nil)
        init!(base_path_str)
      end
      
      def init!(base_path_str=nil)
        debug( "Config: initializing" )  
        @base_path = Pathname.new(base_path_str || ENV["MINFRA_PATH"]).expand_path
        @me_path = @base_path.join('me')
        @project_config_path=@base_path.join("config","project.json")
        @config_path =  @me_path.join('config.json')
        @stacks_path = @base_path.join('stacks')
        @kube_path=@me_path.join('kube')
        @kube_config_path=@kube_path.join('config')
        @kind_config_path=@me_path.join("kind.yaml.erb")
        @project_minfrarc_path = @base_path.join("config",'minfrarc.rb')
        require @project_minfrarc_path if @project_minfrarc_path.exist?
        @me_minfrarc_path = @me_path.join('minfrarc.rb')
        require @me_minfrarc_path if @me_minfrarc_path.exist?
        if config_path.exist?
          @config = Hashie::Mash.new(JSON.parse(Minfra::Cli::Templater.render(File.read(config_path),{}))) 
        else
          warn("personal minfra configuration file '#{config_path}' not found, you might have to run 'minfra setup dev'")
          @config = Hashie::Mash.new({})
        end
        @project = Hashie::Mash.new(JSON.parse(Minfra::Cli::Templater.render(File.read(@project_config_path),{})))
      end

      def load(orch_env)
        debug( "loading config env: #{orch_env} #{@orch_env}" )
        return self if defined?(@orch_env)
        @orch_env = orch_env
        @orch_env_config = @config.environments[@orch_env] || raise(EnvironmentNotFoundError.new("Configuration for orchestration environment '#{@orch_env}' not found. Available orechstration environments: #{@config.environments.keys.inspect}"))
        @project= @project.
                  deep_merge(@project.environments[@orch_env]).
                  deep_merge(@config).
                  deep_merge(@orch_env_config)
        @orch_env_config['env']=@orch_env
        self
      end

      def name
        @project.name
      end

      def describe(environment)
          {
            env: {
              minfra_name: ENV["MINFRA_NAME"],
              minfra_path: ENV["MINFRA_PATH"],
            },
            base_path: base_path.to_s,
            me_path: me_path.to_s,
            kube_path: kube_path.to_s,
            config_path: config_path.to_s,
            config: @config.to_h,
            env_config: @orch_env_config.to_h,
            project: @project
          }
      end
      def dev?
        @orch_env=='dev'
      end

      def email
        @config.identity.email
      end

      def api_key
        @project.account_api_key
      end

      def endpoint(name)
        Hashie::Mash.new({"api_key": api_key}).deep_merge(@project.endpoints[name])
      rescue
        raise("endpoint #{name} is undefinded please add <env>:endpoints:#{name} to you #{config_path} file ")
      end
    end
  end
end
