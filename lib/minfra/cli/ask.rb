# frozen_string_literal: true

module Minfra
  module Cli
    module Ask
      def self.boolean(question)
        answered = false
        until answered
          $stdout.write "#{question} (y/n)"
          answer = $stdin.gets.chomp
          if %w[y n].include?(answer)
            answered = true
          else
            $stdout.write("I just understand 'y' and 'n', again: ")
          end
        end
        answer == 'y'
      end

      def self.text(question, default = nil)
        loop do
          message = format('%s%s: ', question, default && " (#{default})")
          $stdout.write message
          answer = $stdin.gets.chomp
          answer = default if answer == ''
          break unless answer.nil?
        end
        answer
      end

      def self.placeholders(templater, placeholders = {})
        templater.check_missing do |name|
          placeholders[name] = text("I need a value for: #{name}") unless placeholders[name]
        end
        placeholders
      end

      def self.interactive_template(template_file, out_file, placeholders = {})
        templater = Templater.new(File.read(template_file))
        params = self.placeholders(templater, placeholders)
        File.write(out_file, templater.render(params))
      end
    end
  end
end
