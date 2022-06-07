module Minfra
  module Cli
    module Ask
      def self.boolean(question)
        answered = false
        until answered
          STDOUT.write "#{question} (y/n)"
          answer = STDIN.gets.chomp
          if ['y', 'n'].include?(answer)
            answered = true
          else
            STDOUT.write("I just understand 'y' and 'n', again: ")
          end
        end
        answer == 'y'
      end

      def self.text(question, default=nil)
        begin
          message = format('%s%s: ', question, default && " (#{default})")
          STDOUT.write message
          answer = STDIN.gets.chomp
          answer = default if answer == ''
        end while answer.nil?
        answer
      end

      def self.placeholders(templater,placeholders={})
        templater.check_missing do |name|
          placeholders[name]=self.text("I need a value for: #{name}") unless placeholders[name]
        end
        placeholders
      end

      def self.interactive_template(template_file, out_file, placeholders={})
        templater=Templater.new(File.read(template_file))
        params=self.placeholders(templater,placeholders)
        File.write(out_file,templater.render(params))

      end
    end
  end
end
