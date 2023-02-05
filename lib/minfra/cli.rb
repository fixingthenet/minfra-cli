require 'thor'
require 'open3'
require 'json'
require 'ostruct'
require 'hiera'

require_relative 'cli/logging'
require_relative 'cli/templater'

require 'orchparty'
require_relative 'cli/config'
require_relative 'cli/version'
require_relative 'cli/hook'
require_relative 'cli/common'
require_relative 'cli/command'
require_relative 'cli/ask'
require_relative 'cli/document'
require_relative 'cli/runner'
require_relative 'cli/plugins'

require 'active_support'
require 'active_support/core_ext'

require "#{ENV['MINFRA_PATH']}/config/preload.rb" if File.exist?("#{ENV['MINFRA_PATH']}/config/preload.rb")

module Minfra
  module Cli

    extend Minfra::Cli::Logging
    include Minfra::Cli::Hook

    def self.logger
      @logger
    end
    
    def self.init(argv)
     @argv = argv
     # we'll set the context very early!

     if idx=@argv.index("-e")
       @config = Config.load(@argv[idx+1])
       @argv.delete_at(idx)
       @argv.delete_at(idx)
     else
       @config = Config.load('dev')
     end

     @logger=Logger.new(STDERR)
     logger.level=ENV["MINFRA_LOGGING_LEVEL"] || @config.project.minfra.logging_level || 'warn'
     @logger.debug("Minfra: loglevel: #{@logger.level}, env: #{@config.orch_env}")
     
     hiera_init

     @plugins = Minfra::Cli::Plugins.load
     @plugins.prepare
     
     Minfra::Cli.scan
     require_relative 'cli/main_command'
     Minfra::Cli.resolve

     project_minfrarc_path = @config.base_path.join("config",'minfrarc.rb')
     require project_minfrarc_path if project_minfrarc_path.exist?
     me_minfrarc_path = @config.me_path.join('minfrarc.rb')
     require @me_minfrarc_path if me_minfrarc_path.exist?
     
    end
    
    def self.run
      Minfra::Cli::Main.start(@argv)
    end

    def self.root_path
      Pathname.new(File.expand_path(File.join(__FILE__, '../../../')))
    end

    def self.hiera_init
      @hiera_root = Pathname.new("#{ENV["MINFRA_PATH"]}/hiera")
      hiera = Hiera.new(:config => @hiera_root.join('hiera.yaml').to_s)
      Hiera.logger=:noop
      env= @config.orch_env
      hiera_main_path=@hiera_root.join("hieradata/#{config.project.minfra.hiera.env_path}/#{env}.eyaml")
      raise("unknown environment #{env}, I expact a file at #{hiera_main_path}") unless hiera_main_path.exist? 

      scope={ "minfra_path" => ENV["MINFRA_PATH"], "hieraroot" => @hiera_root.to_s, "env" => env}
      special_lookups=hiera.lookup("lookup_options", {},  scope, nil, :priority)
      
      node_scope=hiera.lookup("env", {},  scope, nil, :deeper)
      scope=scope.merge(node_scope)
      cache={}
      Kernel.define_method(:l) do |value,default=nil|

       return cache[value] if cache.has_key?(value)

       values=value.split(".")
       fst_value=values.shift

       if special_lookups[fst_value]
         lookup_type={ merge_behavior: special_lookups[fst_value]["merge"].to_sym }
       else
         lookup_type=:deep
       end

       result=hiera.lookup(fst_value, default, scope, nil, lookup_type)
       if !values.empty? && result.kind_of?(Hash) # we return nil or the scalar value and only drill down on hashes
         result=result.dig(*values)
       end

       result=Hashie::Mash.new(result) if result.kind_of?(Hash)
       cache[value] = result
       result
      end
      Kernel.define_method(:l!) do |value,default=nil|
        v=l(value,default)
        raise("Value not found! #{value}") if v.nil?
        v
      end  
    end


    def self.config
      @config
    end
    
    def self.scan
      #loading built in commands
      root_path.join("lib/minfra/cli/commands").each_child do |command_path|
        require command_path if command_path.to_s.match(/\.rb$/) && !command_path.to_s.match(/\#/)
      end
      @plugins.setup
    end
    
    def self.plugins
      @plugins
    end

    def self.register(subcommand,info,command)
      #debug("Registered command #{subcommand}")
      @subcommands ||= {}
      @subcommands[subcommand.to_sym]= OpenStruct.new(name: subcommand, info: info, command: command)
    end

    def self.resolve
      @subcommands.values.each do |sub|
        Minfra::Cli::Main.desc(sub.name,sub.info)
        Minfra::Cli::Main.subcommand(sub.name,sub.command)
      end
    end

  end
end
