require 'pathname'

module Minfra
  module Cli
    module StackM
      class ClientTemplate
        include ::Minfra::Cli::Logging

        attr_reader :content, :path
        def initialize(stack_name, client_name, config)
          @stack_name  = stack_name
          @client_name = client_name
          @config      = OpenStruct.new
          @path       = config.stacks_path.join(stack_name, "fxnet-client-#{client_name}-#{config.orch_env}.json")
          read
        end

        def exist?
          @path.exist?
        end
          
        def read
          if exist?
            t=Minfra::Cli::Templater.new(File.read(@path))
            @content = Hashie::Mash.new(JSON.parse(t.render({})))
          end
        end

        def to_s
          JSON.generate(@content, {indent: "  ", object_nl: "\n"})
        end

      end
    end
  end
end
