# frozen_string_literal: true

require 'spec_helper'

require 'minfra/cli'

describe Minfra::Cli do
  it 'has a version number' do
    expect(Minfra::Cli::VERSION).not_to be nil
  end

  describe 'CliStarter' do
    let(:minfra_path) { File.expand_path(File.join(__FILE__, '../../fixture/minfra_example')) }
    let!(:main) do
      Minfra::Cli.init(['one', 'two', 'three', '-e', 'test', '--minfra_argv_file', 'hallo.txt', '--minfra_path',
                        minfra_path])
    end

    it 'extracts global_options' do
      expect(main.options).to eq({ env: 'test', argv_file: 'hallo.txt', base_path: minfra_path })
      expect(main.argv).to eq(%w[one two three])
    end

    it 'sets env' do
      expect(main.env_name).to eq('test')
    end

    it 'sets up config correctly' do
      expect(main.config.orch_env).to eq('test')
    end

    it 'registers some subcommands' do
      expect(Minfra::Cli.subcommands).not_to be_empty
    end

    it 'runs a single command' do
      expect(Minfra::Cli.init(['version', '--minfra_path', minfra_path]).run).to eq(0)
    end

    it 'installs minfra_cli in the kernel' do
      main.install
      expect(minfra_cli).to eq(main)
    end
    
    it 'installs l and l! in kernel' do
      main.install
      expect(l('env.name')).to eq('test')
      expect(l!('env.name')).to eq('test')
    end
    
    it 'reads all envs' do
      expect(main.envs.keys).to eq(['dev','test'])
    end

    it 'sets the initialized env' do
      expect(main.env.name).to eq('test')
    end
    
    it 'has an own hiera looker for each env' do
      expect(main.envs['test'].l('env.name')).to eq('test')
      expect(main.envs['dev'].l('env.name')).to eq('dev')
    end
    
    it 'looks up with defaults' do
      expect( main.env.l('env.more_fun', [])).to eq([])
    end
    
    it 'runs commands from a file'
  end
end
