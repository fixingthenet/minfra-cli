# frozen_string_literal: true

require 'spec_helper'

require 'minfra/cli'

describe Minfra::Cli do
  it 'has a version number' do
    expect(Minfra::Cli::VERSION).not_to be nil
  end

  describe 'CliStarter' do
    let!(:main) { Minfra::Cli.init(['one', 'two', 'three', '-e', 'test', '--argv_file', 'hallo.txt']) }

    it 'extracts global_options' do
      expect(main.options).to eq({ env: 'test', argv_file: 'hallo.txt' })
      expect(main.argv).to eq(%w[one two three])
    end

    it 'registers some subcommands' do
      expect(Minfra::Cli.subcommands).not_to be_empty
    end
  end
end
