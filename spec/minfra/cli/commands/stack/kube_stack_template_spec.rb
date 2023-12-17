require 'spec_helper'

require 'minfra/cli'
require 'minfra/cli/commands/stack/kube_stack_template.rb'

RSpec.describe Minfra::Cli::StackM::KubeStackTemplate do
  let!(:main) { Minfra::Cli.init}
  it "should init" do
     config = OpenStruct.new(stacks_path: Pathname.new('/tmp'), status_path: Pathname.new('/tmp/status'))
     Minfra::Cli::StackM::KubeStackTemplate.new("name", config, deployment: nil, cluster: '')
  end
end

