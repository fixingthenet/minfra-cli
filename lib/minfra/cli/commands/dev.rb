# frozen_string_literal: true

require 'fileutils'
module Minfra
  module Cli
    class Dev < Command
      desc 'describe', "get some info about your config (if it's setup)"
      option :environment, required: false, aliases: ['-e']
      def describe
        pp minfra_config.describe(options[:environment])
      end

      desc 'create', 'create your development cluster'
      def create
        kube.create
      end

      desc 'upgrade',
           'upgrade kind (moves previous configs and recreates the cluster; use it if you made changes to config/kind.yaml.erb)'
      def upgrade
        info 'Destroying existing dev cluster..'
        destroy
        Runner.run(
          "mv #{minfra_config.base_path.join('me',
                                             'kind.yaml.erb')} #{minfra_config.base_path.join('me', "kind_old_#{Time.now.strftime('%Y_%m_%dT%H_%M_%SZ')}.yaml.erb")}", print_stdout: true
        )
        Runner.run(
          "mv #{minfra_config.base_path.join('me', 'kube',
                                             'config')} #{minfra_config.base_path.join('me', 'kube', "config_old_#{Time.now.strftime('%Y_%m_%dT%H_%M_%SZ')}")}", print_stdout: true
        )
        Runner.run('yes | minfra setup dev', print_stdout: true) # On an existing cluster this should only ask for recreating the files that we moved previously
        info 'Creating a new dev cluster..'
        create
        info 'I am done upgrading the dev cluster! 🎉'
      end

      desc 'restart', 'restart your development cluster'
      def restart
        kube.restart
      end

      desc 'start', 'start your development cluster'
      def start
        restart
      end

      desc 'destroy', 'tear down your development cluster'
      def destroy
        kube.destroy_dev_cluster
      end

      private

      def kube
        @kube ||= Kube.new(options, minfra_config)
      end
    end
  end
end

Minfra::Cli.register('dev', 'Manage your dev cluster.', Minfra::Cli::Dev)
