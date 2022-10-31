# frozen_string_literal: true

module Minfra
  module Cli
    class Tag
      include Minfra::Cli::Logging

      def initialize
        @now = Time.now.utc
        @format = '%Y_%m_%dT%H_%M_%SZ'
        @tags_folder = '.tags'
      end

      def tag_current_commit_for_deploy(message, format)
        @format = format if format

        info 'Creating tag.'
        debug "Using .tags folder..."
#        write_tag_folder_file(message)
        #run_cmd(cmd_add_tag_info("#{@tags_folder}/#{tag_name}"), :system)
        #run_cmd(cmd_create_tag_commit, :system)
        run_cmd(cmd_tag_commit(message), :system)
#        info 'Pushing tag to remote.'
#        run_cmd(cmd_push, :system)
        run_cmd(cmd_push_tag, :system)
      end

      def ensure_commit_is_pushed
        info 'Checking that the current commit is present on the remote.'
        output = run_cmd(cmd_ensure_commit_is_pushed)

        if output.empty?
          exit_error "The current commit is not present on the remote.\n" \
                     'Please push your changes to origin and try again.'
        end
      end

      def cmd_ensure_commit_is_pushed
        'git branch -r --contains $(git rev-list --max-count=1 HEAD)'
      end

      def cmd_add_tag_info(file)
        "git add #{file}"
      end

      def cmd_create_tag_commit
        "git commit -m '#{tag_name}'"
      end

      def cmd_tag_commit(message)
        "git tag -a #{tag_name} -m '#{message}'"
      end

      def cmd_push
        "git push"
      end

      def cmd_push_tag
        "git push origin #{tag_name}"
      end

      def git_current_branch
        `git rev-parse --abbrev-ref HEAD`.strip
      end
      
      #TBD: this should be more flexible
      def tag_name
        "#{git_current_branch}-REL-#{@now.strftime(@format)}"
      end

      def write_tag_folder_file(message)
        File.write("#{@tags_folder}/#{tag_name}", "#{message}\n")
      end

      def write_tag_file(_message)
        File.write(@tags_file.to_s, "#{tag_name}\n")
      end

      def run_cmd(cmd, _how = :system)
        Runner.run(cmd)
      end
    end
  end
end

#Minfra::Cli.register("tag", "creating tags", Minfra::Cli::Tag)
