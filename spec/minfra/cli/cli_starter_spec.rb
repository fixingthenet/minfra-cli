require 'spec_helper'

RSpec.describe Minfra::Cli::Config do
  let(:minfra_path) {
    File.expand_path(File.join(__FILE__, "../../../fixture/minfra_example"))
  }
  let(:starter) {
    Minfra::Cli::CliStarter.new(['--no-rc', '--minfra_path', minfra_path ])
  }

  it "parses --no-rc option" do
    expect(starter.options[:norc]).to eq(true)
  end
end
