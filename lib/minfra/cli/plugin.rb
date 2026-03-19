# frozen_string_literal: true

module Minfra
  module Cli
    class Plugins
      class Plugin
        include Logging

        def name
          @spec.name
        end
        
        def version
          @spec.version
        end

        def initialize(spec)
          @spec = spec
          @minfracs_path = Pathname.new(spec.full_gem_path).join('minfracs', 'init.rb')
          raise "no init.rb file in #{@minfracs_path}" unless @minfracs_path.exist?
        end

        def setup
          require @minfracs_path # this should register the command
        rescue LoadError
          logger.warn("Minfra plugin detected but dependencies not installed: #{minfra_path} (#{$ERROR_INFO}). TRY: minfra plugin install")
        end
      end
    end
  end
end
