# 4.1.0
 * Minfra::Cli::Templater can now user helper modules
# 4.0.0
 * in apply mode of secrets we prefix the name with the chart name
# 3.1.0
 * overriding backends via MINFRA_HIERA_BACKENDS
 * overriding Yaml Backend to allow :extension: setting
# 3.0.2
 * removing complex dns manipulation and hardcoding google servers
# 3.0.1
 * fixing: dubblequotes in helm values should be escaped
# 3.0.0
 * change: debug output on template errors
 Incompatibility
 * change: used_vars are turned into true yaml types when creating the value file
# 2.2.0
 * fixing: should not modify l('env.roles')
 * cleanup: removing template testing --debug flag, causing noise
 * cleanup: removing Documentation hooks
 * fixing: hiera lookup retrying on gpg memory error exceptions
 * adding: gpgme dependency
# 2.1.0
 * adding: :all hook
 * fixing: setup dev
 * adding: colored errors and warnings
 * change: wrapping hiera lookup errors of gpg
 * adding: HIERA_DEBUG_LOOKUPS=true
# 2.0.1
 Refactorings
 * installing into Kernel only when 'exec' not at 'init' time
# 2.0.0
 Incompatibility
 * dropping ruby < 3.1 support
 * config: NO support for "environment" specific overrides in configs, use hiera
 * only allow to deploy stacks which are in env.roles, env.stacks or project:default_stacks
 * Minfra::Cli.env not supported

 Refactorings/Features 
 * refactoring Cli to CliStarter
 * refactoring Cli to HierLooker
 * support for argv_file to run commands from a file
 * tests: more of them
 * new command: dev envs
 * new Kernel method: minfra_cli which is the CliStarter Object

# 1.13.3
 * BUG: fixing 'label'
# 1.13.2
 * BUG: fixing 'generic_secret'
# 1.13.1
 * BUG: not every deployer contexts have cleanups
# 1.13.0
 * secrets can be rendered with apply (currently hardcoded)
 * moved most output to debug level 
# 1.12.1
 * replaced all relevant system calls with new runners (fixed apply and
   generic_secrets)
# 1.12.0
 * refactoring Runner
 * adding runner type system (popen is default)
 * adding HelmRunner, KubectlRunner
 * adding support for infra::allow_insecure_k8s_connections
 * easing active support requirement

# 1.11.0
 * generating helm output with resolved vairables in "helm_expanded"
 * adding template_dir to templater to render whole directories
# 1.10.0
 * project.json supports exec_params
 * helm values are all strings (so helm doesn't convert them)
# 1.9.0
 * helm template now called with --debug
 * added "file" to service
 * ready for ruby 3.2
 * fixing project build "loading int " typo
 * changing init sequence (first load minfrarc)
 * STDERR of external commands is now written as INFO

# 1.8.0
 * more output which "require" failed when loading dependencies
 * catching closed stream errors in Minfra::Cli::Runner
 * stderr of runner goes to info
 * stdout of runner goes to debug
# 1.7.1
 * fix plugin install edge cases
# 1.7.0
 * rewrite of hooks system
 * deprecation of me/kind.yaml.erb (breaking change as config/kind.yaml.erb the whole config object is passed
 * improving Minfra::Cli::Runner to stream output
# 1.6.2
 * fixing templater 
 * generating Chart.yaml only once with the namespaces name
# 1.6.1
 * adding minfra_path to hiera scope
 * fixing state preparation when state dir not yet there
# 1.6.0
 * collecting things in used_vars 
 * no overwriting of values.yaml between each char (as the helm template dir is shared)
# 1.5.1
 * fixing hiera lookup caching error
# 1.5.0
 * minfra project branch create now supports --prefix, keeps '-' (dash intact) and is config file configurable
 * Minfra::Cli::Config deep merges personal config (again)
# 1.4.4
 * fixing logging on fresh installs
# 1.4.3
 * fixing exec for kubectl wrapper
 * more logger usage less puts
# 1.4.2
 * removing byebug
# 1.4.1
 * kube command supports port-foward and finds the first fuzzy podname 
# 1.4.0
 * plugin managment
 * changed logging (added central logger, and configurable loglevel: MINFRA_LOGGING_LEVEL minfra.logging_level)
 * hiera main path can be configured (minfra.hiera.env_path)
 * fixed kube subcommand
# 1.3.0
 * deep lookup value like "env.cluster.name"
# 1.2.2
 * fixing tagging
# 1.2.1
 * fixing merge
# 1.2.0
 * no .tags any more
# 1.1.0
 
# 1.0.2
 * looking up cluster name by hiera cluster.id
# 1.0.1
 * adding l! method
# 1.0.0
 * adding hiera as dependecy
 * removing self developped inheritance of data

# 0.2.2 Secrets support in charts

# 0.1.0 Initial
 * opensourcing a base state, still WIP!
