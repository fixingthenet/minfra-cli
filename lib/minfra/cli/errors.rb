# frozen_string_literal: true

module Minfra
  module Cli
    module Errors
      class ExitError < StandardError
      end
      class EnvNotFound < StandardError
      end
    end
  end
end
