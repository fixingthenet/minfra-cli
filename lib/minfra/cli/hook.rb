# no support for around hooks yet

module Minfra
  module Cli
    module Hook
      class Hook
        def initialize(type, name, block)
          @type=type
          @name=name
          @block=block
        end

        def match?(type, name)
         @type == type && @name == name
        end

        def exec (obj)
          obj.instance_eval(&@block)
        end

      end

      class Hooker
        def initialize(klass)
          @klass=klass
          @hooks=[]
        end

        def register_before(name, block)
          @hooks << Hook.new(:before, name, block)
        end

        def register_after(name, block)
          @hooks << Hook.new(:after, name, block)
        end

        def call(obj, name, &block)
          @hooks.select do |h| h.match?(:before, name) end.each do |h| h.exec(obj) end
          obj.instance_eval(&block)
          @hooks.select do |h| h.match?(:after, name) end.each do |h| h.exec(obj) end
        end
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def hooks
          @hooker||=Hooker.new(self)
        end
        def after_hook(name,&block)
          hooks.register_after(name, block)
        end
        def before_hook(name, &block)
          hooks.register_before(name, block)
        end
      end

      def with_hook(hook_name, &block)
        self.class.hooks.call(self, hook_name, &block)
      end
    end
  end
end
