# frozen_string_literal: true

module Minfra
  module Cli
    class Project < Command
      class Branch < Command
        desc "create 'story desc'", 'create branch'
        option :prefix, type: :string,
                        desc: "don't use your git email address or project.branch.create.prefix or identity.email"
        option :tag, type: :string, desc: 'overwrite default tag generation'
        option :test, type: :boolean, default: false, desc: "don't create the tag just show the command"
        
        def create(story_desc)
          if options[:tag]
            tag = options[:tag]
          else
            story_desc = story_desc.gsub(/[^0-9a-z-]/i, '_')

            prefix = options[:prefix] || Minfra::Cli.config.project.dig('project', 'branch', 'create', 'prefix')
            unless prefix
              email = Minfra::Cli.config.project.dig('identity', 'email') || `git config user.email`
              fullname = email.split('@').first
              prefix = fullname[0] + fullname.split('.').last
            end

            now = Time.now.utc.strftime('%Y%m%d')
            tag = options[:tag] || "#{prefix}_#{story_desc}_#{now}"
          end

          Runner.run("git checkout -b #{tag}", test: options[:test])
        end
      end
    end
  end
end
