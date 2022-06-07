module Minfra
  module Cli
    class Main < Command

      desc 'kube', 'kubectl wrapper and other features'
      long_desc '
      '
      option :environment, required: false, aliases: ['-e']
      option :cluster
      def kube(*args)
          kube.kubectl_command(args)
      end

      # tbd: move this to project
      desc 'tag', 'tag current commit for deployment - triggers CI'
      option :message, default: 'release', aliases: ['-m']
      option :format, required: false, aliases: ['-f']
      def tag
        Tag.new.tag_current_commit_for_deploy(options[:message], options[:format])
      end

      desc 'version', 'prints version of the cli'
      def version
        puts Minfra::Cli::VERSION
      end

      def self.exit_on_failure?
        true
      end
    end
  end
end
