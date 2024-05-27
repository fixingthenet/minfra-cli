# frozen_string_literal: true

require 'deep_merge'
require 'orchparty/version'
require 'orchparty/ast'
require 'orchparty/context'
require 'orchparty/transformations'
require 'orchparty/dsl_parser'
require 'orchparty/dsl_parser_kubernetes'
require 'orchparty/plugin'
require 'orchparty/kubernetes_application'
require 'hash'

module Orchparty
  def self.options
    @@options
  end

  def self.options=(opt)
    @@options = opt
  end

  class App
    attr_reader :options

    def initialize(cluster_name:, application_name:, force_variable_definition:, file_name:, status_dir:, options: {})
      @cluster_name = cluster_name
      @application_name = application_name
      @force_variable_definiton = force_variable_definition
      @file_name = file_name
      @status_dir = status_dir
      @options = options

      Orchparty.options = options

      load_plugins
    end

    def plugins
      Orchparty::Plugin.plugins
    end

    def print(method:, out_io:)
      res = app(out_io:)
      res.print(method)
      res
    end

    def install
      app.install
    end

    def upgrade
      app.upgrade
    end

    private

    def app(out_io: $stdout)
      parsed = Orchparty::Kubernetes::DSLParser.new(@file_name).parse
      app_config = Transformations.transform_kubernetes(parsed, force_variable_definition: @force_variable_definition).applications[@application_name]
      KubernetesApplication.new(
        app_config:,
        namespace: @application_name,
        cluster_name: @cluster_name,
        file_name: @file_name,
        status_dir: @status_dir,
        out_io:
      )
    end

    def generate(plugin_name, options, plugin_options)
      plugins[plugin_name].generate(ast(options), plugin_options)
    end

    def ast(filename:, application:, force_variable_definition: nil)
      Transformations.transform(Orchparty::DSLParser.new(filename).parse,
                                force_variable_definition:).applications[application]
    end

    def load_plugins
      Gem::Specification.map do |f|
        f.matches_for_glob('orchparty/plugins/*.rb')
      end.flatten.map do |file_name|
        File.basename(file_name,
                      '.*').to_sym
      end.each do |plugin_name|
        plugin(plugin_name)
      end
    end

    def plugin(name)
      Orchparty::Plugin.load_plugin(name)
    end
  end
end
