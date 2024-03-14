module Minfra
  module Cli
    class Env
      attr_reader :name, :hiera
      def initialize(name:, hiera_root:,   hiera_env_path:, hiera_debug_lookups:, backends: )
        @name = name            
        @hiera = HieraLooker.new( 
          root: hiera_root,
          env_name: name,
          env_path: hiera_env_path,
          debug_lookups: hiera_debug_lookups,
          backends: backends
        )
      end
      
      def l(key, value = nil)
        @hiera.l(key,value)
      end
      
      def l!(key, value = nil)
        @hiera.l!(key, value)
      end
      
    end
  end
end