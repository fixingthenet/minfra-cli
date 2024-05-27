# frozen_string_literal: true

require 'yaml'
module Minfra
  module Cli
    class Kube
      include Minfra::Cli::Common
      include Logging

      attr_reader :options, :env_config, :config

      def initialize(options, config)
        @options = options
        @config = config
        @env_config = config.orch_env_config
      end

      def dashboard(stack_name, env, deployment, cluster)
        stack = init(stack_name, env, deployment, cluster)
        insecure_flag = l('infra::allow_insecure_k8s_connections') ? '--insecure-skip-tls-verify' : ''
        cmd = "k9s #{insecure_flag} --kubeconfig #{kube_config_path} --context #{stack.cluster_name} --namespace #{stack_name} --command pod"
        debug(cmd)
        exec(cmd)
      end

      def restart
        run %(docker start #{kind_name}-control-plane)
        set_kind_dns
      end

      def create
        $stdout.sync

        network_mask = @config.project.kind.network.mask
        gateway_ip = @config.project.kind.network.gateway
        panel_ip = @config.project.kind.panel.ip

        info "step: creating network #{kind_name} #{network_mask} gw #{gateway_ip}"
        # run(%{docker network inspect kind | grep "Subnet"}, exit_on_error: false).success?
        run(%(docker network rm #{kind_name}), exit_on_error: false)

        run(%(docker network create --gateway #{gateway_ip} --subnet=#{network_mask} #{kind_name}), exit_on_error: true)

        info "step: creating '#{kind_name}' kind cluster (can take some minutes)"
        kind_kube_path = Runner.run('echo $KUBECONFIG').to_s.strip
        kind_config = Templater.read(config.base_path.join('config', 'kind.yaml.erb'), params: { config: })
        File.write(config.kind_config_path, kind_config)

        run(%(KIND_EXPERIMENTAL_DOCKER_NETWORK=#{kind_name} kind create cluster --name "#{kind_name}" --config #{@config.kind_config_path}))

        info 'step: configuring kind'
        
        set_kind_dns
        
        configs = [YAML.safe_load(File.read(kind_kube_path))]

        existing_config = YAML.safe_load(File.read(kube_config_path))

        existing_config['clusters'] = existing_config['clusters'].reject do |c|
          configs.map do |k|
            k['clusters']
          end.flatten.map { |n| n['name'] }.include?(c['name'])
        end.concat(configs.map do |k|
                     k['clusters']
                   end.flatten)
        existing_config['users'] = existing_config['users'].reject do |c|
                                     configs.map do |k|
                                       k['users']
                                     end.flatten.map { |n| n['name'] }.include?(c['name'])
                                   end.concat(configs.map do |k|
                                                k['users']
                                              end.flatten).uniq { |k| k['name'] }
        existing_config['contexts'] = existing_config['contexts'].reject do |c|
          configs.map do |k|
            k['contexts']
          end.flatten.map { |n| n['name'] }.include?(c['name'])
        end.concat(configs.map do |k|
                     k['contexts']
                   end.flatten)
        File.write(@config.kube_config_path, YAML.dump(existing_config))

        info 'step: starting kind'
        run_kubectl %( config use-context kind-#{kind_name} )

        run_kubectl %(create clusterrolebinding default-admin --serviceaccount=kube-system:default --clusterrole=cluster-admin)

        #        info "step: attaching newly created kind cluster to its own docker network"
        #        info run(%{docker network connect #{kind_name} #{kind_name}-control-plane --ip #{panel_ip}})
      end

      def push(image)
        run %(kind load docker-image --name #{kind_name} #{image})
      end

      def destroy_dev_cluster
        run %(kind delete cluster --name #{kind_name})
        run(%(docker rm -f #{kind_name}-control-plane), exit_on_error: false)
        run(%(docker network rm #{kind_name}), exit_on_error: false)
      end

      def deploy(stack_name, _reason_message)
        # TBD: options is global, avoid it!

        test = options[:test]
        stack = init(stack_name,
                     options[:environment],
                     options[:deployment],
                     options[:cluster])
        cluster = stack.cluster_name

        method = options['install'] ? 'install' : 'upgrade'

        stack.release_path.mkpath

        orch = Orchparty::App.new(cluster_name: cluster,
                             application_name: stack.name,
                             force_variable_definition: false,
                             file_name: stack.stack_rb_path.to_s,
                             status_dir: stack.release_path,
                             options:)

        chart_release_name =nil
        File.open(stack.compose_path, 'w') do |f|
          chart_release_name = orch.print(method:, out_io: f).chart_release_name
        end
        
        # run_cmd(generate_cmd, :bash)
        bash_cmd = ["cd #{stack.release_path}"]
        run_cmd(bash_cmd, :bash)

        # to live diff:
        # old way:
        # run_cmd(["cd #{stack.release_path}", "git --no-pager diff #{stack.release_path}"], :bash, silence: true)
        # kube apply
        # TBD ... kubectl --context kind-ccs --namespace ccs-webapp-service get deployment -o json ccs-webapp-web ????
        # helm upgrade
        info("Will run:")
        run_cmd("cat #{stack.compose_path}", :bash)
        info("Detected diffs on #{stack.compose_path} (uncertain):")
        run_cmd(["cd #{stack.release_path}", "git --no-pager diff #{stack.compose_path}"], :bash)
        
        if chart_release_name && method == 'upgrade'
          info("Will change helmchart:")
          run_helm("diff upgrade --allow-unreleased #{chart_release_name} #{stack.result_path.join('helm')} -n  #{stack.name} --kube-context #{cluster}")
        end  

        errors = stack.check_plan
        unless errors.empty?
          if config['force_mem']
            exit_error(errors.join("\n"))
          else
            warn(errors.join("\n"))
          end
        end

        return if test

        exit_error('Deployment aborted!') if !(@config.dev? || options[:force] == true) && !Ask.boolean('Are the changes ok?')

        orch.send(method)
      end

      def rollback(stack_name, env, deployment, cluster)
        stack = init(stack_name,
                     env,
                     deployment,
                     cluster)

        cluster = stack.cluster_name

        extra_args = args.dup
        extra_args.delete('rollback')

        extra_args = extra_args.join(' ')

        run_helm("--kube-context #{cluster} rollback #{options[:stack]} #{extra_args}")
      end

      def list
        puts run_helm(%(list --all-namespaces))
      end

      def destroy(stack_name)
        stack = init(stack_name,
                     options[:environment],
                     options[:deployment],
                     options[:cluster])
        # Our convention is that our stack name is the namespace in helm.
        # Sometimes the helm release name can be the same as the stack name (usually in the normal stacks).
        # However, stacks that combine multiple helm charts have the release name different from the stack name, that's why we have to list them all in a sub-command.
        run_helm(%{uninstall --namespace #{stack_name} --kube-context #{stack.cluster_name} $(helm list --namespace #{stack_name} --kube-context #{stack.cluster_name} --short)})
      end

      def kubectl_command(args)
        exit_error('You must specify a stack name (--stack).') unless options['stack']

        subcommand = args.shift

        if %w[exec logs port-forward].include?(subcommand)
          resource = nil
          implicit_resource = 'pod'
        else
          resource = args.shift
        end

        stack = init(options[:stack],
                     options[:environment],
                     options[:deployment],
                     options[:cluster])

        cluster = stack.cluster_name
        if [resource,
            implicit_resource].include?('pod') && %w[delete describe exec logs port-forward].include?(subcommand)
          cmd_get_pods = "--kubeconfig #{kube_config_path} --context #{cluster} --namespace #{options[:stack]} get pod -o jsonpath='{range .items[*]}{.metadata.name}{\"\\n\"}'"

          pods_list = run_kubectl(cmd_get_pods).stdout_lines

          fuzzy_pod_name = args.shift

          matching_pods = pods_list.select { |p| p.include?(fuzzy_pod_name) }

          exit_error("Could not find any pods that have '#{fuzzy_pod_name}' in their name.") if matching_pods.empty?

          position = 0
          if options[:position]
            p = options[:position].to_i
            if p <= matching_pods.size
              position = p - 1
            else
              exit_error("You specified '--position #{options[:position]} but only #{matching_pods.size} pods matched the name.")
            end
          end

          pod_name = matching_pods[position]
        end

        extra_args = args.dup

        if subcommand == 'exec'
          subcommand = 'exec -ti'
          extra_args.unshift('--')
          extra_args << 'bash' if args.empty?
        end

        extra_args = extra_args.join(' ')

        cmd = "--kubeconfig #{kube_config_path} --context #{cluster} --namespace #{options[:stack]} #{subcommand} #{resource} #{pod_name} #{extra_args}"
        KubeCtlRunner.run(cmd, runner: :exec)
      end

      private

      def set_kind_dns
        run %(docker exec #{kind_name}-control-plane bash -c "echo nameserver 8.8.8.8 > /etc/resolv.conf")
        run %(docker exec #{kind_name}-control-plane bash -c "echo nameserver 8.8.4.4 >> /etc/resolv.conf")
      end
      
      def init(stack_name, _env, deployment, explicit_cluster)
        Minfra::Cli::StackM::KubeStackTemplate.new(stack_name,
                                                   config,
                                                   deployment:,
                                                   cluster: explicit_cluster)

        #        exit_error(template.error_message) unless template.valid?
      end

      def kube_config_path
        @config.kube_config_path
      end

      def run_kubectl(cmd)
        KubeCtlRunner.run(cmd, runner: :system)
      end

      def run_helm(cmd)
        HelmRunner.run(cmd, runner: :system)
      end

      def helm_path
        @config.me_path.join('helm')
      end

      def kind_name
        @config.name
      end

      def run(cmd, **args)
        Runner.run(cmd, **args)
      end
    end
  end
end
