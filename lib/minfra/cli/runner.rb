# frozen_string_literal: true

require 'English'
require 'open3'

module Minfra
  module Cli
    class Runner
      class Result
        include Logging

        attr_writer :status

        attr_reader :stdout_lines

        def initialize(on_output: nil)
          @stderr_lines = []
          @stdout_lines = []
          @status = nil
          @on_output = on_output
        end

        def add(line, stream = :stdout)
          line.chomp!
          @on_output.call(line, stream) if @on_output
          if stream == :stdout
            @stdout_lines << line
            debug line
          else
            @stderr_lines << line
            info line
          end
        end

        def exitstatus
          @status.exitstatus
        end

        def success?
          @status.success?
        end

        def error?
          !success?
        end

        def stdout
          @stdout_lines.join("\n")
        end

        def stderr
          @stderr_lines.join("\n")
        end

        def to_s
          stdout
        end
      end

      include Logging
      def self.run(cmd, **args)
        new(cmd, **args).run
      end

      attr_reader :exit_on_error, :runner, :cmd, :on_output

      def initialize(cmd, exit_on_error: true, runner: :popen, on_output: nil)
        @cmd = cmd
        @exit_on_error = exit_on_error
        @runner = runner
        @on_output = on_output
      end

      def run
        debug("running (#{@runner}): #{@cmd}")
        res = Result.new(on_output:)
        case @runner
              when :system
                run_system(res)
              when :popen
                run_threaded(res)
              when :exec
                run_exec(res)
              else
                raise "unknown runner #{@runner}"
              end

        if res.error?
          error "command failed: #{@cmd}"
          debug res.stdout
          info res.stderr
        end
        if exit_on_error && res.error?
          info "command exiting on error (#{res.exitstatus})"
          exit 1
        end
        res
      end

      private

      def run_exec(_res)
        exec(@cmd)
      end

      # you don't get stderr .... yet
      def run_system(res)
        # https://stackoverflow.com/questions/6338908/ruby-difference-between-exec-system-and-x-or-backticks
        begin
          out = `#{@cmd}`
          out.each_line { |line| res.add(line, :stdout) }
        rescue StandardError
        end
        res.status = $CHILD_STATUS
        res
      end

      def run_threaded(res)
        begin
          # see: http://stackoverflow.com/a/1162850/83386
          # the whole implementation is problematic as we migth miss some output lines
          # Open4 might be a solution. Using Select might be a solution. Using Process.fork might be a solution....
          Open3.popen3(@cmd) do |_stdin, stdout, stderr, thread|
            # read each stream from a new thread
            { stdout:, stderr: }.each do |key, stream|
              Thread.new do
                until (raw_line = stream.gets).nil?
                  #                   stream.each do |raw_line|
                  res.add(raw_line, key)
                end
              rescue IOError # happens when you read from a close stream
                raise unless ['stream closed in another thread', 'closed stream'].include?($ERROR_INFO.message)
                # warn("Caught: #{$ERROR_INFO.message} for #{@cmd}")
              end
            end
            thread.join # don't exit until the external process is done
            res.status = thread.value
          end
        rescue StandardError
        end
        res
      end
    end
  end
end
