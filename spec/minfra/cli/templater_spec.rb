require 'spec_helper'
require 'debug'
RSpec.describe Minfra::Cli::Templater do

  let(:helper_dir) {
    Minfra::Cli.cli.base_path.join('../erb_helpers/dir')
  }
  
  let(:helper_file) {
    helper_dir.join('some_helper.rb')
  }
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
    expect(temp.render(missing: "not missing")).to eq("jo not missing")
  end
  
  it "includes helper modules" do
    module SomethingFunny
      def fun
        "fun"
      end
    end
    temp = Minfra::Cli::Templater.new("jo <%= fun %>", helpers: [SomethingFunny])
    expect(temp.render({})).to eq("jo fun")
  end
  
  it "has access to params from modules" do
    module SomethingFunny2
      def fun
        outer
      end
    end
    temp = Minfra::Cli::Templater.new("jo <%= fun %>", helpers: [SomethingFunny2])
    expect(temp.render({outer: 'yo!'})).to eq("jo yo!")
    
  end
end
