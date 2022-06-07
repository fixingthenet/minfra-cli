require 'spec_helper'

RSpec.describe Minfra::Cli::Config do
  let(:config) {
    Minfra::Cli::Config.load('dev', File.expand_path(File.join(__FILE__, "../../../fixture/minfra_example")))
  }
  it "initializes correctly" do
    expect(config.dev?).to eq(true)
  end

  it "extracts the config/orch_env config settings" do
    expect(config.config.top_level).to eq('okok')
    expect(config.orch_env_config.one).to eq(1)
  end

  it "treats json file as template" do
    expect(config.orch_env_config.two).to eq("2")
  end
end
