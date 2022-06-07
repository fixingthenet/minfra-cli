require 'open3'

module Minfra
  module Cli
    class Runner
      class Result
        attr_reader :stdout, :stderr
        def initialize(stdout,stderr, status)
          @stderr=stderr
          @stdout=stdout
          @status=status
        end

        def success?
          @status.success?
        end

        def error?
          !success?
        end

        def to_s
          @stdout.to_s
        end
      end

      include Logging
      def self.run(cmd, **args)
        new(cmd, **args).run
      end

      attr_reader :exit_on_error
      def initialize(cmd, exit_on_error: true)
        @cmd=cmd
        @exit_on_error = exit_on_error
      end

      def run
        debug(@cmd)
        res=nil
        begin
          res=Result.new(*Open3.capture3(@cmd))
        rescue
        end  
        if res&.error?
          STDERR.puts "command failed: #{@cmd}"
          STDERR.puts res.stdout
          STDERR.puts res.stderr
        end
        if exit_on_error && res&.error?
          STDERR.puts "exiting on error"
          exit 1
        end
        res
      end

    end
  end
end
