module Minfra
  module Cli
    class Project < Command
      class Branch < Command

        desc "create 'story desc'", 'create branch'
        option :prefix, type: :string, desc: "don't use your git email address or project.branch.create.prefix or identity.email"
        def create(story_desc)
          story_desc = story_desc.gsub(/[^0-9a-z\-]/i, '_')
          prefix = options[:prefix] || Minfra::Cli.config.project.dig('project','branch', 'create', 'prefix')
          unless prefix
            email = Minfra::Cli.config.project.dig('identity', 'email') || `git config user.email`
            fullname = email.split('@').first
            prefix = fullname[0] + fullname.split('.').last
          end  
          Runner.run("git checkout -b #{prefix}_#{story_desc}_$(date +%Y%m%d)")
        end
      end
    end
  end
end
