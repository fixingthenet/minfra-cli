# frozen_string_literal: true

require 'pathname'

module Minfra
  module Cli
    module Common
      include Minfra::Cli::Logging

      def run_cmd(cmd, type = :non_system, silence: false)
        debug(cmd)
        case type
        when :exec
          Kernel.exec(cmd)
        when :bash
          res = system(%(bash -c "#{Array.new(cmd).join(' && ')}"))
          exit_error('failed!') unless res
          nil # no output!
        when :system
          res = system(cmd)
          exit_error('failed!') unless res
          nil # no output!
        else
          `#{cmd}` # with output!
        end
      end

      def parse_cmd(cmd, silence: false)
        reply = JSON.parse(run_cmd(cmd, silence:))
      rescue JSON::ParserError, TypeError
        error "ERROR: #{$ERROR_INFO.message}"
        error reply
        error "command was: #{cmd}"
        exit 1
      end
    end
  end
end
