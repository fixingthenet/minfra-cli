# frozen_string_literal: true

require 'pathname'
require 'hashie/mash'
require 'json'
require_relative 'templater'
module Minfra
  module Cli
    # responsible the read the config file(s) and add a small abstraction layer on top of it
    class Config
      class ConfigNotFoundError < StandardError
      end

      class EnvironmentNotFoundError < StandardError
      end

      attr_reader :base_path, :config_path, :stacks_path, :status_path, :me_path, :kube_path, :kube_config_path,
                  :kind_config_path, :orch_env, :orch_env_config, :config, :project

      def initialize(base_path_str, orch_env)
        init!(base_path_str, orch_env)
      end

      def init!(base_path_str, orch_env)
        @orch_env = orch_env
        @base_path = Pathname.new(base_path_str).expand_path
        @me_path = @base_path.join('me')
        @project_config_path = @base_path.join('config', 'project.json')
        @config_path = @me_path.join('config.json')
        @stacks_path = @base_path.join('stacks')
        @status_path = @base_path.join('state')
        @kube_path = @me_path.join('kube')
        @kube_config_path = @kube_path.join('config')
        @kind_config_path = @me_path.join('kind.yaml')

        if config_path.exist?
          @config = Hashie::Mash.new(JSON.parse(Minfra::Cli::Templater.render(File.read(config_path), {})))
        else
          warn("personal minfra configuration file '#{config_path}' not found, you might have to run 'minfra setup dev'")
          @config = Hashie::Mash.new({})
        end
        @project = Hashie::Mash.new(JSON.parse(Minfra::Cli::Templater.render(File.read(@project_config_path), {})))
        @project = @project
                   .deep_merge(@config)
      end

      def name
        @project.name
      end

      def describe(_environment)
        {
          env: {
            minfra_name: ENV.fetch('MINFRA_NAME', nil),
            minfra_path: ENV.fetch('MINFRA_PATH', nil)
          },
          base_path: base_path.to_s,
          me_path: me_path.to_s,
          kube_path: kube_path.to_s,
          config_path: config_path.to_s,
          config: @config.to_h,
          project: @project
        }
      end

      def dev?
        @orch_env == 'dev'
      end

      def email
        @config.identity.email
      end

      def api_key
        @project.account_api_key
      end

      def endpoint(name)
        Hashie::Mash.new({ api_key: }).deep_merge(@project.endpoints[name])
      rescue StandardError
        raise("endpoint #{name} is undefinded please add <env>:endpoints:#{name} to you #{config_path} file ")
      end
    end
  end
end
