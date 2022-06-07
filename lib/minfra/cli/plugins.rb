module Minfra
  module Cli
    class Plugins
      def self.load
        [Pathname.new(ENV["MINFRA_PATH"]).join("config","minfra_plugins.json"),
        Pathname.new(ENV["MINFRA_PATH"]).join("me","minfra_plugins.json")].each do |file|

          next unless File.exist?(file)

          plugins=JSON.parse(File.read(file))
          plugins["plugins"].each do |spec|
            opts=spec["opts"] || {}
            opts.merge(require: false)
            if opts["path"]
              begin
                $LOAD_PATH.unshift opts["path"]+"/lib"
                require spec["name"]
              rescue Gem::Requirement::BadRequirementError
                STDERR.puts("Can't load plugin: #{spec["name"]}")
              end
            else
              begin
                Gem::Specification.find_by_name(spec["name"])
                gem spec["name"], spec["version"]
              rescue Gem::MissingSpecError
                STDERR.puts("Can't load plugin: #{spec["name"]}, #{spec["version"]}; run 'minfra plugin setup'")
              end
            end
          end  
        end
      end
    end
  end
end
