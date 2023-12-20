require 'spec_helper'

require 'minfra/cli'
require 'minfra/cli/commands/stack/kube_stack_template.rb'

RSpec.describe Minfra::Cli::StackM::KubeStackTemplate do
  let!(:main) { Minfra::Cli.init}
  it "should init" do
     Minfra::Cli::StackM::KubeStackTemplate.new("name", Minfra::Cli.config, deployment: nil, cluster: '')
  end
end

