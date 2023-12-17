# frozen_string_literal: true

require 'pathname'

module Minfra
  module Cli
    module StackM
      class AppTemplate
        include ::Minfra::Cli::Logging

        attr_reader :name, :env, :deployment, :app_path

        def initialize(name, config)
          @name       = name
          @path       = config.stacks_path.join(name)
          @app_path   = @path.join('fxnet-app.json')
          @errors     = []
          @config     = config
          @env        = config.orch_env
          @content    = {}
        end

        def cluster_name
          return @cluster_name if defined?(@cluster_name)

          @cluster_name = @cluster
          @cluster_name ||= "kind-#{@config.name}" if @config.dev?
          if cluster_path.exist? && (@cluster_name.nil? || @cluster_name.empty?)
            @cluster_name = YAML.safe_load(File.read(cluster_path))[env.to_s]
          end
          unless @cluster_name
            error "Cluster name unknown (not given explicitly and '#{cluster_path}' missing)"
            exit 1
          end
          @cluster_name
        end

        def valid?
          @errors << "stack path #{@path} doesn't exist" unless @path.exist?

          @errors << "stack.rb file #{@app_path} doesn't exist" unless @app_path.exist?
          @errors.empty?
        end

        def read
          t = Minfra::Cli::Templater.new(File.read(@app_path))
          @content = Hashie::Mash.new(JSON.parse(t.render({})))
        end

        def app
          @content.app
        end

        def client
          @content.client
        end

        def to_s
          JSON.generate(@content, { indent: '  ', object_nl: "\n" })
        end
      end
    end
  end
end
