require 'open3'

module Minfra
  module Cli
    class Runner
      class Result
        include Logging
        
        attr_writer :status
        
        def initialize
          @stderr_lines=[]
          @stdout_lines=[]
          @status=nil
        end
        
        def add(line, stream=:stdout)
          line.chomp!
          if stream == :stdout
            @stdout_lines << line
            debug line
          else
            @stderr_lines << line
            error line
          end
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

      attr_reader :exit_on_error
      def initialize(cmd, exit_on_error: true)
        @cmd=cmd
        @exit_on_error = exit_on_error
      end

      def run
        debug("running: #{@cmd}")
        res=nil
        begin
          res=Result.new
          # see: http://stackoverflow.com/a/1162850/83386
          Open3.popen3(@cmd) do |stdin, stdout, stderr, thread|
            # read each stream from a new thread
            { :stdout => stdout, :stderr => stderr }.each do |key, stream|
              Thread.new do
                until (raw_line = stream.gets).nil? do
                  res.add(raw_line, key)
                end
              end
            end
            thread.join # don't exit until the external process is done
            res.status = thread.value
          end
        rescue
        end
        
        if res.error?
          error "command failed: #{@cmd}"
          info  res.stdout
          error res.stderr
        end
        if exit_on_error && res.error?
          info "exiting on error"
          exit 1
        end
        res
      end
    end
  end
end
