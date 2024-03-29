# frozen_string_literal: true

module Minfra
  module Cli
    class HelmRunner < Runner
      def initialize(cmd, **args)
        insecure_flag = l('infra::allow_insecure_k8s_connections') ? '--kube-insecure-skip-tls-verify' : ''
        cmd = "helm #{insecure_flag} #{cmd}"
        super(cmd, **args)
      end
    end
  end
end
