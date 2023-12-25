# frozen_string_literal: true

module Orchparty
  class Context < ::Hashie::Mash
    include Hashie::Extensions::DeepMerge
    include Hashie::Extensions::DeepMergeConcat
    include Hashie::Extensions::MethodAccess
    include Hashie::Extensions::Mash::KeepOriginalKeys

    def method_missing(name, *args)
      raise "#{name} not declared for #{application.name}.#{service.name}" if @_force_variable_definition && !key?(name) && !key?(name.to_s)

      super
    end

    attr_writer :_force_variable_definition

    def context
      self
    end
  end
end
