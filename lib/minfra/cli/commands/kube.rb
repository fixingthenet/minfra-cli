require 'yaml'
module Minfra
  module Cli
    class Kube
      include Minfra::Cli::Common
      include Logging

      attr_reader :options, :env_config, :config

      def initialize(options, config)
        @options = options
        @config=config
        @env_config=config.orch_env_config
      end

      def dashboard(stack_name,env,deployment,cluster)
        stack = init(stack_name,env,deployment,cluster)
        exec("k9s --kubeconfig #{kube_config_path} --context #{stack.cluster_name} --namespace #{stack_name} --command pod")
      end

      def restart
        run %{docker start #{kind_name}-control-plane}
        run %{docker exec  #{kind_name}-control-plane bash -c "sed -e '/nameserver 127.0.0.11/ s/^#*/#/'  /etc/resolv.conf | cat - >> /etc/resolv.conf"}
        run %{docker exec  #{kind_name}-control-plane bash -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"}
        run %{docker exec  #{kind_name}-control-plane bash -c "echo nameserver 8.8.4.4 >> /etc/resolv.conf"}
      end

      def create
        STDOUT.sync

        network_mask = @config.project.kind.network.mask
        gateway_ip = @config.project.kind.network.gateway
        panel_ip = @config.project.kind.panel.ip

        info "step: creating network #{kind_name} #{network_mask} gw #{gateway_ip}"
        # run(%{docker network inspect kind | grep "Subnet"}, exit_on_error: false).success?
        run(%{docker network rm #{kind_name}}, exit_on_error: false)

        run(%{docker network create --gateway #{gateway_ip} --subnet=#{network_mask} #{kind_name}}, exit_on_error: true)

        info "step: creating '#{kind_name}' kind cluster (can take some minutes)"
        kind_kube_path=Runner.run('echo $KUBECONFIG').to_s.strip
        info run(%{KIND_EXPERIMENTAL_DOCKER_NETWORK=#{kind_name} kind create cluster --name "#{kind_name}" --config #{@config.kind_config_path}})

        info "step: configuring kind"
        run %{docker exec #{kind_name}-control-plane bash -c "sed -e '/nameserver 127.0.0.11/ s/^#*/#/'  /etc/resolv.conf | cat - >> /etc/resolv.conf"}
        run %{docker exec #{kind_name}-control-plane bash -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"}
        run %{docker exec #{kind_name}-control-plane bash -c "echo nameserver 8.8.4.4 >> /etc/resolv.conf"}

        configs = [YAML.load(File.read(kind_kube_path))]

        existing_config = YAML.load(File.read(kube_config_path))

        existing_config["clusters"] = existing_config["clusters"].reject { |c| configs.map { |k| k["clusters"] }.flatten.map { |n| n["name"] }.include?(c["name"]) }.concat(configs.map { |k| k["clusters"] }.flatten)
        existing_config["users"] = existing_config["users"].reject { |c| configs.map { |k| k["users"] }.flatten.map { |n| n["name"] }.include?(c["name"]) }.concat(configs.map{ |k| k["users"] }.flatten).uniq { |k| k["name"] }
        existing_config["contexts"] = existing_config["contexts"].reject { |c| configs.map { |k| k["contexts"] }.flatten.map{ |n| n["name"] }.include?(c["name"]) }.concat(configs.map { |k| k["contexts"] }.flatten)
        File.write(@config.kube_config_path, YAML.dump(existing_config))

        info "step: starting kind"
        run_kubectl %{ config use-context kind-#{kind_name} }

        run_kubectl %{create clusterrolebinding default-admin --serviceaccount=kube-system:default --clusterrole=cluster-admin}

#        info "step: attaching newly created kind cluster to its own docker network"
#        info run(%{docker network connect #{kind_name} #{kind_name}-control-plane --ip #{panel_ip}})
      end

      def push(image)
        run %{kind load docker-image --name #{kind_name} #{image}}
      end

      def destroy_dev_cluster
        run %(kind delete cluster --name #{kind_name})
        run(%(docker rm -f #{kind_name}-control-plane), exit_on_error: false)
        run(%(docker network rm #{kind_name}), exit_on_error: false) 
      end

      def deploy(stack_name, reason_message)
        #TBD: options is global, avoid it!
        
        test=options[:test]
        stack = init(stack_name,
                     options[:environment],
                     options[:deployment],
                     options[:cluster])
        cluster = stack.cluster_name

        method = options["install"] ? "install" : "upgrade"

        stack.release_path.mkpath
        
        File.open(stack.compose_path,"w") do |f|
          Orchparty::App.new(cluster_name: cluster, 
                        application_name: stack.name, 
                        force_variable_definition: false, 
                        file_name: stack.stack_rb_path.to_s,
                        status_dir: stack.release_path,
                        options: options
                        ).
                        print( method: method, out_io: f)
        end
        #run_cmd(generate_cmd, :bash)
        bash_cmd = ["cd #{stack.release_path}"]
        run_cmd(bash_cmd, :bash)


        run_cmd(["cd #{stack.release_path}",
                 "git --no-pager diff #{stack.release_path}",
        ], :bash, silence: true)

        errors = stack.check_plan
        unless errors.empty?
          if config['force_mem']
            exit_error(errors.join("\n"))
          else
            warn(errors.join("\n"))
          end
        end

        unless test
          unless @config.dev? || options[:force]==true
            unless Ask.boolean("Are the changes ok?")
              exit_error("Deployment aborted!")
            end
          end

#          deploy_cmd = bash_cmd
#          deploy_cmd << "#{env_cmd} orchparty #{method} -c #{cluster} -f #{stack.stack_rb_path}  -a #{stack.name}"

          reason_message = tag_changed_to(release_path: stack.release_path) if reason_message.blank?

          message =  "deploying stack #{stack.name}: #{reason_message}."
          Minfra::Cli::Document.document(@config,"started #{message}")
          orch=Orchparty::App.new(cluster_name: cluster, 
                        application_name: stack.name, 
                        force_variable_definition: false, 
                        file_name: stack.stack_rb_path.to_s,
                        status_dir: stack.release_path,
                        options: options
                        )
          orch.send(method)
          Minfra::Cli::Document.document(@config,"finished #{message}")
        end
      end

      def rollback(stack_name, env, deployment, cluster)
        stack = init(stack_name,
                     env,
                     deployment,
                     cluster)

        cluster = stack.cluster_name

        extra_args = args.dup
        extra_args.delete("rollback")

        extra_args = extra_args.join(' ')

        cmd = "helm --kube-context #{cluster} rollback #{options[:stack]} #{extra_args}"
        #puts cmd
        run_cmd(cmd, :exec)
      end

      def list
        puts run_helm(%{list --all-namespaces})
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
        unless options['stack']
          exit_error("You must specify a stack name (--stack).")
        end

        subcommand = args.shift

        if ['exec', 'logs','port-forward'].include?(subcommand)
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
        if [resource, implicit_resource].include?('pod') && ['delete', 'describe', 'exec', 'logs', 'port-forward'].include?(subcommand)
          cmd_get_pods = "kubectl --kubeconfig #{kube_config_path} --context #{cluster} --namespace #{options[:stack]} get pod -o jsonpath='{range .items[*]}{.metadata.name}{\"\\n\"}'"

          pods_list = run_cmd(cmd_get_pods).split("\n")

          fuzzy_pod_name = args.shift

          matching_pods = pods_list.select { |p| p.include?(fuzzy_pod_name) }

          if matching_pods.empty?
            exit_error("Could not find any pods that have '#{fuzzy_pod_name}' in their name.")
          end

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

        cmd = "kubectl --kubeconfig #{kube_config_path} --context #{cluster} --namespace #{options[:stack]} #{subcommand} #{resource} #{pod_name} #{extra_args}"
        # puts cmd
        run_cmd(cmd, :exec)
      end

      private

      def tag_changed_to(release_path:)
        return '' if @config.dev? # We don't use messages in dev

        diff = run_cmd("cd #{release_path} && git --no-pager diff --unified=0 tags.json").split %r{(\d{4}_\d{2}_\d{2}T\d{2}_\d{2}_\d{2}Z)}

        raise ArgumentError.new "#{release_path}/tags.json has not changed - supply message" if diff.empty?

        diff[3]
      end

      def init(stack_name, env, deployment, explicit_cluster)
        template = Minfra::Cli::StackM::KubeStackTemplate.new(stack_name,
                                                        config,
                                                        deployment: deployment,
                                                        cluster: explicit_cluster)

#        exit_error(template.error_message) unless template.valid?
        template
      end

      def kube_config_path
        @config.kube_config_path
      end

      def run_kubectl(cmd)
        #        run(%{kubectl --kubeconfig #{kube_config_path} #{cmd}})
        run(%{kubectl #{cmd}})
      end

      def run_helm(cmd)
#        run(%{helm --kubeconfig #{kube_config_path} --home #{helm_path} #{cmd}})
        run(%{helm #{cmd}})
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
