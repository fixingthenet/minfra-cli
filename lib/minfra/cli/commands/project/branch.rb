module Minfra
  module Cli
    class Project < Command
      class Branch < Command

        desc "create 'story desc'", 'create branch'
        def create(story_desc)
          story_desc = story_desc.gsub(/[^0-9a-z]/i, '_')
          email = `git config user.email`
          fullname = email.split('@').first
          name = fullname[0] + fullname.split('.').last
          Runner.run("git checkout -b #{name}_#{story_desc}_$(date +%Y%m%d)")
        end
      end
    end
  end
end
