# frozen_string_literal: true

require 'erb'
module Minfra
  module Cli
    # not threadsafe!
    class Templater
      class TemplateBinding
        def _binding
          @binding ||= binding
        end
      end
      #see https://apidock.com/ruby/v2_5_5/ERB/result_with_hash
      class ERBPlus < ERB
         def result_with(hash: {}, helpers: [])
           b = TemplateBinding.new
           hash.each_pair do |key, value|
             b.define_singleton_method(key) do value end
           end
           helpers.each do |helper|
             b.extend helper
           end
           result(b._binding)
         end
      end
      
      def self.read(path, params: {}, fallback: nil)
        p = Pathname.new(path)
        if p.exist?
          content = File.read(path)
        else
          raise "file #{path} not found" unless fallback

          content = fallback

        end
        render(content, params)
      end

      def self.render(template, params, helpers: [])
        new(template, helpers: ).render(params)
      end

      def self.template_dir(src, dst, extensions, helpers: [], params: {})
        destination = Pathname.new(dst)
        destination.mkpath
        source = Pathname.new(src)

        source.glob('**/*') do |filename|
          rel_path = filename.relative_path_from(source)
          if File.directory?(filename) # check if it s  file and extension is not .tf
            FileUtils.mkdir_p("#{destination}/#{rel_path}")
          elsif extensions.include?(File.extname(filename)) # a file
#            puts("templating: #{filename}")
            content = File.read(filename)
            modified_content = Minfra::Cli::Templater.render(content, params, helpers: )
            File.write("#{destination}/#{rel_path}", modified_content)
          else
#            puts("copying  : #{filename}")
            FileUtils.cp(filename, destination.join(rel_path))
          end
        end
      end

      def initialize(template, helpers: [])
        @erb = ERBPlus.new(template)
        @check_mode = false
        @check_missing = []
        @helpers = helpers
      end

      def missing?
        !check_missing.empty?
      end

      def check_missing(&block)
        begin
          @check_mode = true
          @check_block = block
          @check_missing = []
          @erb.result(binding)
        ensure
          @check_block = nil
          @check_mode = false
        end
        @check_missing
      end

      def render(params)
        @erb.result_with(hash: params, helpers: @helpers)
      end

      def method_missing(name)
        if @check_mode
          @check_block&.call(name)
          @check_missing << name
        else
          super
        end
      end
      
    end
  end
end
