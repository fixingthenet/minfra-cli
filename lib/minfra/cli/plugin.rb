# frozen_string_literal: true

module Minfra
  module Cli
    class Plugins
      class Plugin
        include Logging
        attr_reader :name, :version, :opts, :path

        def initialize(name:, version:, opts:, disabled:)
          @name = name
          @version = version
          @opts = opts.merge(require: false)
          @disabled = disabled
          return unless opts['path']

          @path = Minfra::Cli.config.base_path.join(opts['path'])
        end

        def disabled?
          @disabled
        end

        # adds the plugin to the
        def prepare
          debug("plugin prepare: #{name}, #{version}, disabled: #{disabled?}")
          return if disabled?

          if path
            begin
              lib_path = path.join('lib')
              $LOAD_PATH.unshift lib_path
              require name
            rescue Gem::Requirement::BadRequirementError, LoadError
              warn("plugin prepare path: #{name} (#{$ERROR_INFO})")
            end
          else
            begin
              @gem_spec = Gem::Specification.find_by_name(name)
              gem name, version
            rescue Gem::MissingSpecError
              warn("plugin prepare gem: #{name}, #{version} (#{$ERROR_INFO})")
            end
          end
        end

        def setup
          return if disabled?

          if path
            minfra_path = Pathname.new(path).join('minfracs', 'init.rb')
            if minfra_path.exist?
              begin
                require minfra_path # this should register the command
              rescue LoadError
                logger.warn("Minfra plugin detected but dependencies not installed: #{minfra_path} (#{$ERROR_INFO}). TRY: minfra plugin install")
              end
            end
          else
            error('Gem based plugins not supported yet')
          end
        end
      end
    end
  end
end
