require 'spec_helper'

require 'minfra/cli'

describe Minfra::Cli do
  it 'has a version number' do
    expect(Minfra::Cli::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(true).to eq(true)
  end
end
