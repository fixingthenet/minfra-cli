# frozen_string_literal: true

class HashUtils
  def self.transform_hash(original, options = {}, &block)
    original.each_with_object({}) do |(key, value), result|
      value = if options[:deep] && value.is_a?(Hash)
                transform_hash(value, options, &block)
              elsif value.is_a?(Array)
                value.map do |v|
                  if v.is_a?(Hash)
                    transform_hash(v, options, &block)
                  else
                    v
                  end
                end
              else
                value
              end
      block.call(result, key, value)
    end
  end

  # Convert keys to strings, recursively
  def self.deep_stringify_keys(hash)
    transform_hash(hash, deep: true) do |hash, key, value|
      hash[key.to_s] = value
    end
  end
end
