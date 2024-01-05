require 'spec_helper'

RSpec.describe Minfra::Cli::Config do
  let(:mconfig) {
    Minfra::Cli::Config.new(File.expand_path(File.join(__FILE__, "../../../fixture/minfra_example")), 'dev')
  }
  
  it "initializes correctly" do
    expect(mconfig.dev?).to eq(true)
  end

  it "treats json file as template" do
    expect(mconfig.project.two).to eq("2")
  end
end
