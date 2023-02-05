require 'fileutils'
require_relative 'stack/app_template'
require_relative 'stack/client_template'
require_relative 'stack/kube_stack_template'

module Minfra
  module Cli
    class Stack < Command

      desc "describe","get information about a stack"
      option :environment, aliases: ['-e']
      def describe
        pp @minfra_config.describe(options["environment"])
      end

      desc "dashboard <stack_name>", "openening a dashboard for a stack"
      option :environment, aliases: ['-e']
      option :deployment, aliases: ['-d']
      option :cluster, aliases: ['-c']
      def dashboard(stack_name='all')
        kube.dashboard(stack_name, options[:environment], options[:deployment], options[:cluster])
      end

      desc "deploy <stack_name> '<message> (optional)'", "deploy a complete stack"
      option :environment, aliases: ['-e']
#      option :deployment, aliases: ['-d']
      option :cluster, aliases: ['-c']
      option :dev, type: :boolean # currently, about to be changed
      option :explain, type: :boolean
      option :install, type: :boolean
      option :test, type: :boolean
      option :opts
      option :force, type: :boolean
      def deploy(stack_name, message='')
        kube.deploy(stack_name, message)
      end

      desc "rollback <extraargs>", "rollback a deployment"
      option :environment, aliases: ['-e']
      option :deployment, aliases: ['-d']
      option :cluster, aliases: ['-c']
      def rollback(*args)
        STDERR.puts "needs implementation"
        exit 1
        #kube.rollback(stack_name, options[:environment], options[:deployment], options[:cluster], args)
      end

      desc "destroy", "remove the whole stack"
      option :environment, aliases: ['-e']
      option :cluster, aliases: ['-c']
      def destroy(stack_name)
        kube.destroy(stack_name)
      end

      desc "list", "list all stacks in an environment"
      option :environment, aliases: ['-e']
      option :cluster, aliases: ['-c']
      def list
        kube.list
      end

      desc "app", "show the app a stack provides"
      option :environment, aliases: ['-e']
      def app(stack_name)
        cluster=nil
        deployment=nil
        template = Minfra::Cli::StackM::AppTemplate.new(stack_name, minfra_config)
        template.read
        puts "Template: #{template.app_path}\n#{template.to_s}"
        apps = AppResource.all(filter: {identifier: template.app.identifier} ).data
        if apps.empty?
          puts "Auth: app uninstalled"
          atts = {
            identifier: template.app.identifier,
            name: template.app.name,
            short_name: template.app.short_name,
            description: template.app.description,
            native: template.app.native,
            start_url: template.app.start_url,
            public: template.app.public
          }
          app_res=AppResource.build( {data: {attributes: atts, type: 'apps'}} )
          app_res.save
          app = app_res.data
        else
          app = apps.first  
        end    
        puts "Auth: app installed #{app.id}"

        clients = OauthClientResource.all(filter: {app_id: app.id}).data
          if clients.empty?
            puts "Auth: client not registered"
            atts= {redirect_uris: template.client.redirect_uris.map { |r| "#{app.start_url}#{r}" }, 
                   native: template.client.native, ppid: template.client.ppid, name: template.client.name, app_id: app.id}
            client_res=OauthClientResource.build( {data: {attributes: atts, type: 'oauth_clients'}} )
            client_res.save
            client=client_res.data
          else
            client = clients.first
          end
          puts "Auth: client registered #{client.id}"

          client_template=Minfra::Cli::StackM::ClientTemplate.new(stack_name, client.name, minfra_config)
          unless client_template.exist?
            File.write(client_template.path.to_s, { name: client.name, identifier: client.identifier, secret: client.secret }.to_json)
          end
          

        # TODO: create app configuration
        # TODO: create provider
      end

       private
       def kube
         Kube.new(options, @minfra_config)
       end
    end
  end
end

Minfra::Cli.register("stack", "dealing wit stacks", Minfra::Cli::Stack)
