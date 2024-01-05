# frozen_string_literal: true

require 'shellwords'
module Orchparty
  module Plugin
    module Env
      def self.desc
        'generate environment variables'
      end

      def self.define_flags(c)
        c.flag %i[output o], desc: 'Set the output file'
        c.flag %i[service s], desc: 'Set the service to generate environment variables from.'
        c.flag %i[seperator sep], desc: 'How to join the environment variables', default_value: '\\n'
      end

      def self.generate(ast, options)
        output = env_output(ast, options)
        if options[:output]
          File.write(options[:output], output)
        else
          print output
        end
      end

      def self.env_output(application, options)
        services = if options[:service]
                     [application.services[options[:service]]]
                   else
                     application.services.values
                   end

        options[:sep] = "\n" if options[:sep] == '\\n'

        envs = services.map(&:environment).compact.inject({}) { |a, v| a.merge(v) }
        envs.map { |k, v| "#{k}=#{v.is_a?(String) ? v.shellescape : v}" }.join(options[:sep])
      end
    end
  end
end

Orchparty::Plugin.register_plugin(:env, Orchparty::Plugin::Env)
