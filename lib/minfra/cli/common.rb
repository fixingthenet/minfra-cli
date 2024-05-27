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
          res = system(%(bash -c "#{Array(cmd).join(' && ')}"))
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

    end
  end
end
