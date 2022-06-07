require 'pathname'
module Minfra
  module Cli
    module StackM
      class KubeStackTemplate
      include ::Minfra::Cli::Logging

      attr_reader :name, :env, :deployment
      def initialize(name, config, deployment: '', cluster:)
        @name       = name
        @path       = config.stacks_path.join(name)
        @errors     = []
        @config     = config
        @env        = config.orch_env
        @deployment = deployment.freeze
        @cluster    = cluster.freeze
        puts "Stack selection: #{@name}, #{@path}, #{@cluster}"
      end

      def cluster_name
        return @cluster_name if defined?(@cluster_name)
        @cluster_name = @cluster
        @cluster_name ||= "kind-#{@config.name}" if @config.dev?
        if cluster_path.exist? && (@cluster_name.nil? || @cluster_name.empty?)
            @cluster_name = YAML.load(File.read(cluster_path))[env.to_s]
        end
        @cluster_name ||= env
        @cluster_name
      end

      def mixin_env
        "#{@env}#{dashed(@deployment)}"
      end

      def valid?
        unless @path.exist?
          @errors << "stack path #{@path} doesn't exist"
        end

        unless stack_rb_path.exist?
          @errors << "stack.rb file #{stack_rb_path} doesn't exist"
        end
        @errors.empty?
      end

      def stack_rb_path
        release_path.join('stack.rb')
      end

      def cluster_path
        release_path.join("cluster.yaml")
      end

      def compose_path(blank: false)
        if blank
          release_path.join("compose.yaml")
        elsif @cluster
          release_path.join("compose#{dashed(@cluster)}.yaml")
        else
          release_path.join("compose#{dashed(@env)}#{dashed(@deployment)}.yaml")
        end
      end

      def error_message
        @errors.join(";\n")
      end

      # we use a special file to flag the this stack is releasable to an environment
      def releasable?
        switch_path.exist?
      end

      def switch_path
        release_path.join("#{@env}_#{rancher_stack_name}.sh")
      end

      def release_path
        @path
      end


      def check_plan
        errors = []
        errors
      end

      private
      def dashed(sth,set=nil)
        sth.nil? || sth.empty? ? '' : "-#{set||sth}"
      end
    end
  end
end
end
