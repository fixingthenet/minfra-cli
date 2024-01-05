$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'timecop'

require 'minfra/cli'

# RSpec configure documentation: http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|

  config.before(:suite) do 
    minfra_path =  File.expand_path(File.join(__FILE__, "../fixture/minfra_example"))
    Minfra::Cli.init(['--minfra_path', minfra_path])
  end


  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.expose_dsl_globally = true
  config.order = :random
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  Kernel.srand config.seed
end