module Minfra
  module Cli
    class Env
      attr_reader :name, :hiera
      def initialize(name:, hiera_root:,   hiera_env_path:)
        @name = name            
        @hiera = HieraLooker.new( 
          root: hiera_root,
          env_name: name,
          env_path: hiera_env_path
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