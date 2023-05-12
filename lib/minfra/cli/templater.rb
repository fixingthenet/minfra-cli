require 'erb'

module Minfra
  module Cli
    class Templater # not threadsafe!
      def self.read(path, params: {}, fallback: nil)
        p=Pathname.new(path)
        if p.exist?
          content=File.read(path)
        else
          if fallback
            content=fallback
          else
            raise "file #{path} not found"
          end
        end  
        render(content, params)
      end
      
      def self.render(template, params)
        new(template).render(params)
      end

      def self.template_dir(src, dst, extensions)
        destination = Pathname.new(dst)
        destination.mkpath
        source = Pathname.new(src)
        
        source.glob('**/*') do |filename|
          rel_path = filename.relative_path_from(source)

          if File.directory?(filename) # check if it s  file and extension is not .tf
            FileUtils.mkdir_p("#{destination}/#{rel_path}")
          elsif extensions.include?(File.extname(filename)) # a file
            content = File.read(filename)
            modified_content = Minfra::Cli::Templater.render(content, {})
            File.write("#{destination}/#{rel_path}", modified_content)
          else
            FileUtils.cp(filename, destination.join(rel_path))
          end
        end
      end
      
      def initialize(template)
        @erb = ERB.new(template)
        @check_mode=false
        @check_missing=[]
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
        @erb.result_with_hash(params)
      end

      def method_missing(name)
        if @check_mode
          if @check_block
            @check_block.call(name)
          end
          @check_missing << name
        else
          super
        end
      end
    end
  end
end
