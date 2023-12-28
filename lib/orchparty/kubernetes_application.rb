# frozen_string_literal: true

require 'English'
require 'erb'
require 'erubis'
require 'open3'
require 'ostruct'
require 'yaml'
require 'tempfile'
require 'active_support'
require 'active_support/core_ext'

module Orchparty
  module Services
    class Context
      include ::Minfra::Cli::Logging

      attr_accessor :cluster_name, :namespace, :dir_path, :app_config, :options, :service

      def initialize(cluster_name:, namespace:, file_path:, app_config:, app:, service:, out_io: $stdout)
        self.cluster_name = cluster_name
        self.namespace = namespace
        self.dir_path = file_path
        self.app_config = app_config
        @app = app
        @out_io = out_io
        self.service = service # ugly naming, should be 'context'?
        self.options = options
      end

      def template(file_path, helm, flag: '-f ', fix_file_path: nil)
        return '' unless file_path

        debug "Rendering: #{file_path}"
        file_path = File.join(dir_path, file_path) unless file_path.start_with?('/')
        if file_path.end_with?('.erb')
          helm.application = OpenStruct.new(cluster_name: cluster_name, namespace: namespace)
          template = Erubis::Eruby.new(File.read(file_path))
          template.filename = file_path
          yaml = template.result(helm.get_binding)
          file = Tempfile.new('kube-deploy.yaml')
          file.write(yaml)
          file.close
          file_path = file.path
        end
        "#{flag}#{fix_file_path || file_path}"
      end

      def print_install
        @out_io.puts '---'
        @out_io.puts install_cmd(value_path).cmd
        @out_io.puts upgrade_cmd(value_path).cmd
        @out_io.puts '---'
        @out_io.puts File.read(template(value_path, service, flag: '')) if value_path
        cleanup if respond_to?(:cleanup)
      end

      # On 05.02.2021 we have decided that it would be best to print both commands.
      # This way it would be possible to debug both upgrade and install and also people would not see git diffs all the time.
      def print_upgrade
        print_install
      end

      def upgrade
        @out_io.puts upgrade_cmd.run.stdout
        cleanup if respond_to?(:cleanup)
      end

      def install
        @out_io.puts install_cmd.run.stdout
        cleanup if respond_to?(:cleanup)
      end
    end

    class Helm < Context
      def value_path
        service[:values]
      end

      def upgrade_cmd(fix_file_path = nil)
        Minfra::Cli::HelmRunner.new("upgrade --namespace #{namespace} --kube-context #{cluster_name} --version #{service.version} #{service.name} #{service.chart} #{template(
          value_path, service, fix_file_path: fix_file_path
        )}")
      end

      def install_cmd(fix_file_path = nil)
        Minfra::Cli::HelmRunner.new("install --create-namespace --namespace #{namespace} --kube-context #{cluster_name} --version #{service.version} #{service.name} #{service.chart} #{template(
          value_path, service, fix_file_path: fix_file_path
        )}")
      end
    end

    class Apply < Context
      def value_path
        service[:tmp_file] || service[:name]
      end

      def upgrade_cmd(fix_file_path = nil)
        Minfra::Cli::KubeCtlRunner.new("apply --namespace #{namespace} --context #{cluster_name} #{template(value_path,
                                                                                                            service, fix_file_path: fix_file_path)}")
      end

      def install_cmd(fix_file_path = nil)
        Minfra::Cli::KubeCtlRunner.new("apply --namespace #{namespace} --context #{cluster_name} #{template(value_path,
                                                                                                            service, fix_file_path: fix_file_path)}")
      end

      def cleanup
        File.unlink(service[:tmp_file]) if service[:tmp_file]
      end
    end

    class SecretGeneric < Context
      def value_path
        service[:from_file]
      end

      def upgrade_cmd(fix_file_path = nil)
        install_cmd(fix_file_path)
      end

      def install_cmd(fix_file_path = nil)
        cmd="kubectl --namespace #{namespace} create secret generic --dry-run=client -o yaml #{service[:name]}  #{template(value_path, service, flag: '--from-file=')} > #{tempfile.path}"
        res = system(cmd)
        Minfra::Cli::KubeCtlRunner.new("apply --context #{cluster_name} -f #{tempfile.path}")
      end
      
      def cleanup
        tempfile.unlink
      end

      private
      
      def tempfile
        @tempfile ||= Tempfile.new('secret_generic')
      end
      
    end

    class Label < Context
      def print_install
        @out_io.puts '---'
        @out_io.puts install_cmd
      end

      def print_upgrade
        @out_io.puts '---'
        @out_io.puts upgrade_cmd
      end

      def upgrade_cmd
        install_cmd
      end

      def install_cmd
        Minfra::Cli::KubeCtlRunner.new("label --namespace #{namespace} --context #{cluster_name} --overwrite #{service[:resource]} #{service[:name]} #{service['value']}")
      end
    end

    class Wait < Context
      def print_install
        @out_io.puts '---'
        @out_io.puts service.cmd
      end

      def print_upgrade
        @out_io.puts '---'
        @out_io.puts service.cmd
      end

      def upgrade
        eval(service.cmd)
      end

      def install
        eval(service.cmd)
      end
    end

    class Chart < Context
      class CleanBinding
        def get_binding(params)
          params.instance_eval do
            binding
          end
        end
      end

      def print_install
        build_chart do |chart_path|
          cmd = "helm template --namespace #{namespace} --debug --kube-context #{cluster_name} --output-dir #{chart_path.join(
            '..', 'helm_expanded'
          )}   #{service.name} #{chart_path}"
          @out_io.puts `$cmd`
          if system("#{cmd} > /dev/null")

            debug('Helm: template check: OK')
          else
            error('Helm: template check: FAIL')
          end
        end
      end

      def print_upgrade
        print_install
      end

      def install
        debug("Install: #{service.name}")
        build_chart do |chart_path|
          res = Minfra::Cli::HelmRunner.new("install --create-namespace --namespace #{namespace} --kube-context #{cluster_name} #{service.name} #{chart_path}").run
          @out_io.puts res.stdout
        end
      end

      def upgrade
        debug("Upgrade: #{service.name}: #{service._services.join(', ')}")
        build_chart do |chart_path|
          res = Minfra::Cli::HelmRunner.new("upgrade --namespace #{namespace} --kube-context #{cluster_name} #{service.name} #{chart_path}").run
          @out_io.puts res.stdout
        end
      end

      private

      def build_chart
        dir = @app.status_dir.join('helm') # duplication
        params = service._services.map { |s| app_config.services[s.to_sym] }.map { |s| [s.name, s] }.to_h
        run(templates_path: File.expand_path(service.template, dir_path), params: params, output_chart_path: dir,
            chart: service)
        yield dir
      end

      # remember:
      # this is done for an app
      # that app can have multiple charts with multiple services!

      def run(templates_path:, params:, output_chart_path:, chart:)
        File.open(File.join(output_chart_path, 'values.yaml'), 'a') do |helm_values|
          params.each do |app_name, subparams|
            subparams[:chart] = chart
            used_vars = generate_documents_from_erbs(
              templates_path: templates_path,
              app_name: app_name,
              params: subparams,
              output_chart_path: output_chart_path
            )
            used_vars.each do |variable, value|
              helm_values.puts "#{variable}: \"#{value}\""
            end
          end
        end
      end

      def generate_documents_from_erbs(templates_path:, app_name:, params:, output_chart_path:)
        if params[:kind].nil?
          warn "ERROR: Could not generate service '#{app_name}'. Missing key: 'kind'."
          exit 1
        end

        kind = params.fetch(:kind)
        params._used_vars = {} # here we'll collect all used vars

        Dir[File.join(templates_path, kind, '*.erb')].each do |template_path|
          debug("Rendering Template: #{template_path}")
          template_name = File.basename(template_path, '.erb')
          output_path = File.join(output_chart_path, 'templates', "#{app_name}-#{template_name}")

          template = Erubis::Eruby.new(File.read(template_path))
          template.filename = template_path

          params.app = @app
          params.app_name = app_name
          params.templates_path = templates_path
          begin
            document = template.result(CleanBinding.new.get_binding(params))
          rescue Exception
            error "#{template_path} has a problem: #{$ERROR_INFO.inspect}"
            raise
          end
          File.write(output_path, document)
        end
        params._used_vars
      end
    end
  end
end

class KubernetesApplication
  include Minfra::Cli::Logging

  attr_accessor :cluster_name, :file_path, :namespace, :app_config
  attr_reader :status_dir

  def initialize(namespace:, cluster_name:, file_name:, status_dir:, app_config: [], out_io: $stdout)
    self.file_path = Pathname.new(file_name).parent.expand_path # path of the stack
    self.cluster_name = cluster_name
    self.namespace = namespace
    self.app_config = app_config
    @status_dir = status_dir
    @out_io = out_io
  end

  def install
    each_service(:install)
  end

  def upgrade
    each_service(:upgrade)
  end

  def print(method)
    each_service("print_#{method}".to_sym)
  end

  private

  def prepare
    output_chart_path = @status_dir.join('helm')
    output_chart_path.rmtree if output_chart_path.exist?
    output_chart_path.mkpath
    templates_path = file_path.join('../../chart-templates').expand_path # don't ask. the whole concept of multiple charts in an app stinks...

    generate_chart_yaml(
      templates_path: templates_path,
      output_chart_path: output_chart_path,
      chart_name: namespace
    )

    debug("Minfra: generating base helm structure from: #{output_chart_path} from #{templates_path}")
    system("mkdir -p #{File.join(output_chart_path, 'templates')}")

    system("cp #{File.join(templates_path, 'values.yaml')} #{File.join(output_chart_path, 'values.yaml')}")
    system("cp #{File.join(templates_path, '.helmignore')} #{File.join(output_chart_path, '.helmignore')}")
    system("cp #{File.join(templates_path,
                           'templates/_helpers.tpl')} #{File.join(output_chart_path, 'templates/_helpers.tpl')}")
  end

  def generate_chart_yaml(templates_path:, output_chart_path:, chart_name:)
    template_path = File.join(templates_path, 'Chart.yaml.erb')
    output_path = File.join(output_chart_path, 'Chart.yaml')

    res = Minfra::Cli::Templater.read(template_path, params: { chart_name: chart_name })
    File.write(output_path, res)
  end

  def combine_charts(app_config)
    services = app_config._service_order.map(&:to_s)
    app_config._service_order.each do |name|
      current_service = app_config[:services][name]
      next unless current_service._type == 'chart'

      current_service._services.each do |n|
        services.delete n.to_s
      end
      #      else
      #        puts "unkown service: #{name}: #{current_service._type}"
    end
    services
  end

  def each_service(method)
    prepare
    services = combine_charts(app_config)

    services.each do |name|
      service = app_config[:services][name]
      debug("Generating Service: #{name}(#{service._type}) #{method}")
      deployable_class = "::Orchparty::Services::#{service._type.classify}".constantize
      deployable = deployable_class.new(cluster_name: cluster_name,
                                        namespace: namespace,
                                        file_path: file_path,
                                        app_config: app_config,
                                        out_io: @out_io,
                                        app: self,
                                        service: service)
      deployable.send(method)
    end
  end
end
