module Minfra
  module Cli
    class KubeCtlRunner < Runner
      def initialize(cmd, **args)
        insecure_flag = l("infra::allow_insecure_k8s_connections") ? "--insecure-skip-tls-verify" : ""
        cmd = "kubectl #{insecure_flag} #{cmd}"
        super(cmd, **args)
      end
    end
  end
end
