require_relative 'project/branch'
require_relative 'project/tag'

module Minfra
  module Cli
    class Project < Command
      class ProjectInfo
        def self.load(app_dir)
          new(app_dir)
        end
        attr_reader :app_dir

        def initialize(app_dir)
          @app_dir=app_dir
          @project_file_path=app_dir.join('project.json')
          @info=Hashie::Mash.new(JSON.parse(File.read(@project_file_path)))
        end
        def repo_name
          "#{docker.repo}/#{docker.name}"
        end
        def name
          @info['project']
        end
        def method_missing(method)
          @info.send(method)
        end
        def inspect
          @info.inspect
        end
      end

      desc 'branch', 'manage branches'
      subcommand 'branch', Branch

      desc 'tag', 'manage tags'
      subcommand 'tag', Tag

      desc "test", 'run tests'
      def test
        ARGV.delete('project') # ARGV is passed along to `rspec` call
        ARGV.delete('test')

        if File.exist?('./bin/run_tests')
          # config = Config.load('staging')
          project = ProjectInfo.load(Pathname.pwd)
          # Minfra::Cli::Document.document(config, "Using project specific ./bin/run_tests in #{project.name}")
          debug "Using project specific ./bin/run_tests in #{project.name}"
          system('./bin/run_tests', out: $stdout, err: :out)
        else
          require_relative '../../generic/bin/run_tests'
        end
      end

      desc "build","build a local build"
      option "noload", aliases: ['-n']
      option "target", aliases: ['-t'] 
      def build
        p=ProjectInfo.load(Pathname.pwd)
        run_pre_repo
        if options[:target]
          target = options[:target]
        else
          target = p.docker.dev_target
        end
          
        cmd = %{docker build #{"--target #{target}" if target} -t #{p.repo_name}:latest #{p.app_dir}}
        res = Runner.run(cmd)
        exit(1) if res.error?
        
        unless options[:noload]
          debug("loading image into KIND's registry")
          Runner.run(%{kind load docker-image #{p.repo_name}:latest --name #{minfra_config.name}})
        end  
      end

      desc "exec","execute a command (bash is default in the container)"
      def exec(cmd='/bin/bash')
        p=ProjectInfo.load(Pathname.pwd)
        run_pre_repo
        Kernel.exec(%{docker run -ti --rm  #{p.exec_params} -v #{p.app_dir}:/code #{p.repo_name}:latest #{cmd}})
      end

      desc "push", "push directly to the repo"
      option 'tag', aliases: ['-t']
      option 'registry', aliases: ['-r']
      def push
        tag = options[:tag] || `date +%Y%m%d%H%M`
        p=ProjectInfo.load(Pathname.pwd)

        repo_name = if options[:registry]
            "#{options[:registry]}/#{p.repo_name}"
          else
            p.repo_name
          end
          
        Runner.run(%{docker build -t #{p.repo_name}:latest #{p.app_dir}})
#        Runner.run(%{docker push #{p.repo_name}})
        Runner.run(%{docker tag #{p.repo_name}:latest #{repo_name}:#{tag}})
        Runner.run(%{docker push #{repo_name}:#{tag}})
      end



      private
      def run_pre_repo
        Runner.run(%{#{minfra_config.base_path.join('hooks','pre_repo.sh')}})
      end
    end
  end
end


Minfra::Cli.register("project", "dealing wit projects", Minfra::Cli::Project)
