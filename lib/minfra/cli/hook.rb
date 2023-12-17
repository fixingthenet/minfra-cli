# frozen_string_literal: true

# no support for around hooks yet

class Thor
  class Command
    def run(instance, args = [])
      arity = nil

      if private_method?(instance)
        instance.class.handle_no_command_error(name)
      elsif public_method?(instance)
        hooks = instance.instance_variable_get(:@_invocations).values.flatten
        arity = instance.method(name).arity
        Minfra::Cli.call_before_hooks(instance, hooks)
        instance.__send__(name, *args)
        Minfra::Cli.call_after_hooks(instance, hooks)
      elsif local_method?(instance, :method_missing)
        # Minfra::Cli.call_before_hooks(instance,hooks)
        instance.__send__(:method_missing, name.to_sym, *args)
        # Minfra::Cli.call_after_hooks(instance,hooks)
      else
        instance.class.handle_no_command_error(name)
      end
    rescue ArgumentError => e
      if handle_argument_error?(instance, e,
                                caller)
        instance.class.handle_argument_error(self, e, args, arity)
      else
        (raise e)
      end
    rescue NoMethodError => e
      handle_no_method_error?(instance, e, caller) ? instance.class.handle_no_command_error(name) : (raise e)
    end
  end
end

module Minfra
  module Cli
    module Hook
      class Hook
        def initialize(type, names, block)
          @type = type
          @names = names
          @block = block
        end

        def match?(type, names)
          @type == type && @names == names.map(&:to_sym)
        end

        def exec(obj)
          obj.instance_eval(&@block)
        end
      end

      class Hooker
        include Logging
        def initialize(klass)
          @klass = klass
          @hooks = []
        end

        def register_before(names, block)
          @hooks << Hook.new(:before, names, block)
        end

        def register_after(names, block)
          @hooks << Hook.new(:after, names, block)
        end

        def call_before_hooks(obj, names)
          @hooks.select { |h| h.match?(:before, names) }.each do |h|
            debug("Hook before: #{names.join(',')}")
            h.exec(obj)
          end
        end

        def call_after_hooks(obj, names)
          @hooks.select { |h| h.match?(:after, names) }.each do |h|
            debug("Hook  after: #{names.join(',')}")
            h.exec(obj)
          end
        end
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def after_hook(*names, &block)
          hooks.register_after(names, block)
        end

        def before_hook(*names, &block)
          hooks.register_before(names, block)
        end

        def call_before_hooks(obj, names)
          hooks.call_before_hooks(obj, names)
        end

        def call_after_hooks(obj, names)
          hooks.call_after_hooks(obj, names)
        end

        private

        def hooks
          @hooks ||= Hooker.new(self)
        end
      end
    end
  end
end
