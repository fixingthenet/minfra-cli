# frozen_string_literal: true

module Minfra
  module Cli
    class Project < Command
      class TagCli < Command
        default_command :create
        # tbd: move this to project
        desc 'create', 'tag current commit for deployment - triggers CI'
        option :message, default: 'release', aliases: ['-m']
        option :format, required: false, aliases: ['-f']
        def create
          puts Tag.new.tag_current_commit_for_deploy(options[:message], options[:format])
        end
      end
    end
  end
end
