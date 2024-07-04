require_relative 'lib/minfra/cli/version'

Gem::Specification.new do |spec|
  spec.name          = "minfra-cli"
  spec.version       = Minfra::Cli::VERSION
  spec.authors       = ["Peter Schrammel"]
  spec.email         = ["peter.schrammel@gmx.de"]

  spec.summary       = %q{A cli framework for k8s based development and deployment.}
  spec.description   = %q{A cli framework for k8s based development and deployment.}
  spec.homepage      = "https://github.com/fixingthenet/minfra-cli"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fixingthenet/minfra-cli"
  spec.metadata["changelog_uri"] = "https://github.com/fixingthenet/minfra-cli/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_runtime_dependency 'thor', '~> 1.0', '>= 1.0.0'
  spec.add_runtime_dependency "table_print", "~> 1.5"
  spec.add_runtime_dependency "rest-client", "~>2.0"
  spec.add_runtime_dependency "hashie", "~>3.5"
  spec.add_runtime_dependency "activesupport", ">= 7"
  spec.add_runtime_dependency "erubis", "~> 2.7"
  spec.add_runtime_dependency "hiera", "~> 3.9"
  spec.add_runtime_dependency "hiera-eyaml", "~> 3.3"
  spec.add_runtime_dependency "hiera-eyaml-gpg", "~> 0.7"
  spec.add_runtime_dependency "gpgme", "~>2.0"
end
