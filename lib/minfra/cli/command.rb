module Minfra
  module Cli
    class Command < Thor
      include Common
      include Logging
      include Hook

      attr_reader :minfra_config
      no_commands do
        def invoke_command(*args)
            begin
              subcommand_name = args.first.name.to_sym
              with_hook(subcommand_name) do
                @minfra_config = Minfra::Cli.config
                @minfra_config.load(options['environment']) if options['environment']
                @cli_args = args[1]
               super(*args)
              end
            rescue Minfra::Cli::Config::ConfigNotFoundError => err
              STDERR.puts(err.message)
              STDERR.puts "please run 'minfra setup dev'"
              exit 1
            rescue Minfra::Cli::Config::EnvironmentNotFoundError => err
              STDERR.puts(err.message)
              exit 1
            end
        end
        def cli_args
          @args
        end

      end
    end
  end
end
