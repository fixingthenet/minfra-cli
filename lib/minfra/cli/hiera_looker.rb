# frozen_string_literal: true

module Minfra
  module Cli
    class HieraLooker
      def initialize(root:, env_name:, env_path:)
        @root = Pathname.new(root)
        @env_name = env_name
        @cache = {}

        @hiera = Hiera.new(config: @root.join('hiera.yaml').to_s)
        Hiera.logger = :noop

        hiera_main_path = @root.join("hieradata/#{env_path}/#{env_name}.eyaml")

        raise("unknown environment #{@env_name}, I expect a file at #{hiera_main_path}") unless hiera_main_path.exist?

        scope = { 'hieraroot' => @root.to_s, 'env' => @env_name }

        @special_lookups = @hiera.lookup('lookup_options', {}, scope, nil, :priority)
        
        node_scope = @hiera.lookup('env', {}, scope, nil, :deeper)
        @scope = scope.merge(node_scope)
      end

      def l(value, default = nil)
        return @cache[value] if @cache.key?(value)

        values = value.split('.')
        fst_value = values.shift

        lookup_type = if @special_lookups[fst_value]
                        { merge_behavior: @special_lookups[fst_value]['merge'].to_sym }
                      else
                        :deep
                      end
        result = @hiera.lookup(fst_value, default, @scope, nil, lookup_type)
        result = result.dig(*values) if !values.empty? && result.is_a?(Hash) # we return nil or the scalar value and only drill down on hashes

        result = Hashie::Mash.new(result) if result.is_a?(Hash)
        @cache[value] = result
        result
      end

      def l!(value, default)
        v = l(value, default)
        raise("Value not found! #{value}") if v.nil?
        v
      end
      
    end
  end
end
