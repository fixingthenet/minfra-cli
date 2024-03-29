# frozen_string_literal: true

require 'pathname'
require 'securerandom'
module Orchparty
  module Kubernetes
    class DSLParser
      attr_reader :filename

      def initialize(filename)
        @filename = filename
      end

      def parse
        file_content = File.read(filename)
        builder = RootBuilder.new
        builder.instance_eval(file_content, filename)
        builder._build
      end
    end

    class Builder
      def self.build(*args, block)
        builder = new(*args)
        builder.instance_eval(&block) if block
        builder._build
      end

      def assign_or_merge(node, key, value)
        node[key] = if node[key]
                      node[key].deep_merge_concat(value)
                    else
                      value
                    end
      end
    end

    class RootBuilder < Builder
      def initialize
        @root = AST.root
      end

      def import(rel_file)
        old_file_path = Pathname.new(caller[0][/[^:]+/]).parent
        rel_file_path = Pathname.new rel_file
        new_file_path = old_file_path + rel_file_path
        file_content = File.read(new_file_path)
        instance_eval(file_content, new_file_path.expand_path.to_s)
      end

      def application(name, &block)
        @root.applications[name] = ApplicationBuilder.build(name, block)
        self
      end

      def mixin(name, &block)
        @root._mixins[name] = MixinBuilder.build(name, block)
        self
      end

      def _build
        @root
      end
    end

    class MixinBuilder < Builder
      def initialize(name)
        @mixin = AST.mixin(name:)
      end

      def template(path)
        chart_name = '_mixin_temp_name'
        unless @mixin.services[chart_name]
          @mixin.services[chart_name] = AST.chart(name: chart_name, _type: 'chart')
          @mixin._service_order << chart_name
        end
        chart = @mixin.services[chart_name]
        chart.template = path
        self
      end

      def service(name, &block)
        chart_name = '_mixin_temp_name'
        unless @mixin.services[chart_name]
          @mixin.services[chart_name] = AST.chart(name: chart_name, _type: 'chart')
          @mixin._service_order << chart_name
        end
        chart = @mixin.services[chart_name]

        result = ServiceBuilder.build(name, 'chart-service', block)

        name = "chart-#{chart.name}-#{name}"
        @mixin.services[name] = result
        @mixin._service_order << name
        chart._services << name
        self
      end

      def helm(name, &block)
        result = ServiceBuilder.build(name, 'helm', block)
        @mixin.services[name] = result
        @mixin._mixins[name] = result
        self
      end

      def apply(name, &block)
        result = ServiceBuilder.build(name, 'apply', block)
        @mixin.services[name] = result
        @mixin._mixins[name] = result
        self
      end

      def mixin(name, &block)
        @mixin._mixins[name] = ServiceMixinBuilder.build(name, block)
      end

      def volumes(&block)
        @mixin.volumes = HashBuilder.build(block)
      end

      def networks(&block)
        @mixin.networks = HashBuilder.build(block)
      end

      def _build
        @mixin
      end
    end

    class ApplicationBuilder < Builder
      def initialize(name)
        @application = AST.application(name:)
      end

      def mix(name)
        @application._mix << name
      end

      def mixin(name, &block)
        @application._mixins[name] = ApplicationMixinBuilder.build(block)
        self
      end

      def all(&block)
        @application.all = AllBuilder.build(block)
        self
      end

      def variables(&block)
        @application._variables = VariableBuilder.build(block)
        self
      end

      def volumes(&block)
        @application.volumes = HashBuilder.build(block)
        self
      end

      def helm(name, &block)
        result = ServiceBuilder.build(name, 'helm', block)
        @application.services[name] = result
        @application._service_order << name
        self
      end

      def label(&block)
        name = SecureRandom.hex
        result = ServiceWithoutNameBuilder.build('label', block)
        @application.services[name] = result
        @application._service_order << name
        self
      end

      def apply(name, &block)
        result = ServiceBuilder.build(name, 'apply', block)
        @application.services[name] = result
        @application._service_order << name
        self
      end

      def secret_generic(name, &block)
        result = ServiceBuilder.build(name, 'secret_generic', block)
        @application.services[name] = result
        @application._service_order << name
        self
      end

      def wait(&block)
        name = SecureRandom.hex
        result = ServiceBuilder.build(name, 'wait', block)
        @application.services[name] = result
        @application._service_order << name
        self
      end

      def chart(name, &block)
        @application.services[name] = ChartBuilder.build(name, @application, 'chart', block)
        @application._service_order << name
        self
      end

      def template(path)
        chart_name = @application.name
        unless @application.services[chart_name]
          @application.services[chart_name] = AST.chart(name: chart_name, _type: 'chart')
          @application._service_order << chart_name
        end
        chart = @application.services[chart_name]
        chart.template = path
        self
      end

      def service(name, &block)
        chart_name = @application.name
        unless @application.services[chart_name]
          @application.services[chart_name] = AST.chart(name: chart_name, _type: 'chart')
          @application._service_order << chart_name
        end
        chart = @application.services[chart_name]

        result = ServiceBuilder.build(name, 'chart-service', block)

        name = "chart-#{chart.name}-#{name}"
        @application.services[name] = result
        @application._service_order << name
        chart._services << name
        self
      end

      def _build
        @application
      end
    end

    class HashBuilder < Builder
      def method_missing(_, *values, &block)
        if block_given?
          value = HashBuilder.build(block)
          if values.count == 1
            @hash ||= AST.hash
            @hash[values.first.to_sym] = value
          else
            @hash ||= AST.array
            @hash << value
          end
        else
          value = values.first
          if value.is_a? Hash
            @hash ||= AST.hash
            key, value = value.first
            begin
              @hash[key.to_sym] = value
            rescue StandardError
              warn "Problem with key: #{key} #{value}"
              raise
            end

          else
            @hash ||= AST.array
            @hash << value
          end
        end
        self
      end

      def _build
        @hash
      end
    end

    class VariableBuilder < HashBuilder
      def _build
        super || {}
      end
    end

    class CommonBuilder < Builder
      def initialize(node)
        @node = node
      end

      def mix(name)
        @node._mix << name
      end

      def method_missing(name, *values, &block)
        if block_given?
          assign_or_merge(@node, name, HashBuilder.build(block))
        else
          assign_or_merge(@node, name, values.first)
        end
      end

      def _build
        @node
      end

      def variables(&block)
        @node._variables ||= {}
        @node._variables = @node._variables.merge(VariableBuilder.build(block))
        self
      end
    end

    class AllBuilder < CommonBuilder
      def initialize
        super AST.all
      end
    end

    class ApplicationMixinBuilder < CommonBuilder
      def initialize
        super AST.application_mixin
      end
    end

    class ServiceWithoutNameBuilder < CommonBuilder
      def initialize(type)
        super AST.service(_type: type)
      end
    end

    class ServiceBuilder < CommonBuilder
      def initialize(name, type)
        super AST.service(name:, _type: type)
        @node.files = {}
      end

      # 1. rememebring the secrets in environment_secrets (so these environments can be created differentyly
      # 2. create Secret sections
      def environment_secrets(&block)
        result = HashBuilder.build(block)
        @node.environment_secrets = result
        self
      end

      def file(name, volume, &block)
        result = FileBuilder.build(name, volume, block)
        @node.files[name] = result
        self
      end
    end

    class FileBuilder < CommonBuilder
      def initialize(name, volume)
        super AST.service(filename: name, volume:)
      end
    end

    class ServiceMixinBuilder < CommonBuilder
      def initialize(name)
        super AST.service(name:)
      end
    end

    class ChartBuilder < CommonBuilder
      def initialize(name, application, type)
        super AST.chart(name:, _type: type)
        @application = application
      end

      def service(name, &block)
        result = ServiceBuilder.build(name, 'chart-service', block)

        name = "chart-#{@node.name}-#{name}"
        @application.services[name] = result
        @application._service_order << name
        @node._services << name
        self
      end

      # secrets can be aprt of the helm chart or we write them to
      # a file and later apply it
      # apiVersion: v1
      # kind: Secret
      # metadata:
      #  name: dotfile-secret
      # data:
      #  key: base64_encoded_value

      def secrets(name, deploy: :helm, &block)
        case deploy
        when :helm
          result = ServiceBuilder.build(name, 'chart-secret', block)
          @application.services[name] = result
          @application._service_order << name
          @node._services << name
          self
        when :apply
          result = ServiceBuilder.build(name, 'apply', block)
          file = Tempfile.create(name)
          result.tmp_file = file.path
          file.puts "apiVersion: v1\nkind: Secret\nmetadata:\n  name: #{@node.name}-#{name}\ntype: Opaque\ndata:"
          result._.each do |key, value|
            file.puts "  #{key}: #{Base64.strict_encode64(value.respond_to?(:call) ? value.call : value)}"
          end
          file.close
          @application.services[name] = result
          @application._service_order << name
        when :none

        else
          raise "unknown secret type: #{type}, known tpyes: [helm, apply]"
        end
      end
    end
  end
end
