require 'spec_helper'

RSpec.describe Minfra::Cli::Templater do

  it "lists all missing variables" do
    temp = Minfra::Cli::Templater.new("jo <%= missing %>")
    expect(temp.check_missing).to eq([:missing])
  end

  it "runs a block for each missing" do
    missing = []
    temp = Minfra::Cli::Templater.new("jo <%= missing %>")
    temp.check_missing do |name|
      missing << name.to_s
    end
    expect(missing).to eq(['missing'])
  end

  it "renders a template and replaces placeholders" do
    temp = Minfra::Cli::Templater.new("jo <%= missing %>")
    expect(temp.render(missing:  "not missing")).to eq("jo not missing")
  end
end
