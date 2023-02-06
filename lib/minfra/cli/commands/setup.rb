require 'fileutils'
module Minfra
  module Cli
    class Setup < Thor # not from command! # Dev
      include Logging
      include Hook

      desc "dev", "creates a default config file on the host"
      def dev
        setup_config
      end

      private

      def setup_config
        config= Minfra::Cli.config
        ensure_path_and_template(config.config_path, config.base_path.join('config','me_config.json.erb'))
        config.init!
        config.load('dev')
        
      end

      def ensure_path_and_template(dest_path, template_path, params={})
        unless dest_path.exist?
          if Ask.boolean("missing configuration at: #{dest_path}, should I create it?")
            unless dest_path.dirname.exist?
              info "Generated directory '#{dest_path.dirname}'"
              FileUtils.mkdir_p(dest_path.dirname)
            end
            template=Ask.interactive_template(template_path,dest_path,params)
          else
            error "Leaving your filesystem untouched! But I have to stop!"
            exit 1
          end
        else
          info "SETUP CONFIG: checked #{dest_path}"
        end
      end
    end
  end
end

Minfra::Cli.register("setup", "Manage your dev setup.", Minfra::Cli::Setup)
