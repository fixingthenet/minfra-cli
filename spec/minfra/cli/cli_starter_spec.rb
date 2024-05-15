require 'spec_helper'

RSpec.describe Minfra::Cli::Config do
  let(:minfra_path) {
    File.expand_path(File.join(__FILE__, "../../../fixture/minfra_example"))
  }
  let(:starter) {
    Minfra::Cli::CliStarter.new(['--no-rc', '--minfra_path', minfra_path, '--minfra_argv_file', 'file.csv', '-e', 'test' ])
  }

  it "parses --no-rc option" do
    expect(starter.options[:norc]).to eq(true)
  end
  
  it "parses --minfa_path" do
    expect(starter.base_path.to_s).to eq(minfra_path)
    expect(starter.options[:base_path]).to eq(minfra_path)
  end
  
  it "parses --minfra_argv_file" do
    expect(starter.options[:argv_file]).to eq('file.csv')
  end
  
  it 'parses -e environment name' do
    expect(starter.options[:env]).to eq('test')
    expect(starter.env_name).to eq('test')
  end
end
