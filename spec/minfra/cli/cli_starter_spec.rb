require 'spec_helper'

RSpec.describe Minfra::Cli::Config do
  let(:starter) {
    Minfra::Cli::CliStarter.new(['--no-rc'])
  }

  it "parses --no-rc option" do
    expect(starter.options[:norc]).to eq(true)
  end
end