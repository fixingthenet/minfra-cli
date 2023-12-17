# frozen_string_literal: true

module Minfra
  module Cli
    class Project < Command
      class Tag < Command
        desc 'update', 'update stack tag file'
        option 'environment', aliases: ['-e'], required: true
        def update(domain, new_tag)
          tags = JSON.parse(File.read(tags_path))

          raise ArgumentError, "#{path} doesn't contain #{domain}" unless tags[options[:environment]].key?(domain)

          tags[options[:environment]][domain] = new_tag
          pretty_tags = JSON.pretty_unparse(tags)
          File.write(tags_path, "#{pretty_tags}\n")
          puts "#{tags_path} - UPDATED"
          puts pretty_tags
        end

        private

        def tags_path
          apps_path.join('stacks', stack_name, 'tags.json')
        end

        def apps_path
          minfra_config.base_path
        end

        def stack_name
          current_directory.split('/').last.gsub('_', '-')
        end

        def current_directory
          Dir.getwd
        end
      end
    end
  end
end
