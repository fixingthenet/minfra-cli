require 'thor'
require 'open3'
require 'json'
require 'ostruct'
require 'orchparty'
require 'hiera'

require_relative 'cli/logging'
require_relative 'cli/config'
require_relative 'cli/version'
require_relative 'cli/hook'
require_relative 'cli/common'
require_relative 'cli/command'
require_relative 'cli/templater'
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

     hiera_init

     Minfra::Cli::Plugins.load
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
      raise("unknown environment #{env}, I expact a file at hiera/hieradata/environments/#{env}.eyaml") unless @hiera_root.join("hieradata/environments/#{env}.eyaml").exist? 

             
      scope={ "hieraroot" => @hiera_root.to_s, "env" => env}
      special_lookups=hiera.lookup("lookup_options", {},  scope, nil, :priority)
      
      node_scope=hiera.lookup("env", {},  scope, nil, :deeper)
      scope=scope.merge(node_scope)
      cache={}

      Kernel.define_method(:l) do |value,default=nil|
       return cache[value] if cache.has_key?(value)

       if special_lookups[value]
         lookup_type={ merge_behavior: special_lookups[value]["merge"].to_sym }
       else
         lookup_type=:native #priority
       end

       result=hiera.lookup(value, default, scope, nil, lookup_type)
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
      root_path.join("lib/minfra/cli/commands").each_child do |command_path|
        require command_path if command_path.to_s.match(/\.rb$/) && !command_path.to_s.match(/\#/)
      end
      # this is like railties but their called minfracs
      $LOAD_PATH.each do |path|
        minfra_path = Pathname.new(path).join("..","minfracs","init.rb")
        if minfra_path.exist?
          require minfra_path # this should register the command
        end
      end
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

    def self.subcommand(name)
      @subcommands[name.to_sym]&.command
    end

    def self.before_hook(subcommand, command, &block)
      subcommand(subcommand).before_hook(command, &block)
    end

    def self.after_hook(subcommand, command, &block)
      subcommand(subcommand).after_hook(command, &block)
    end
  end
end
