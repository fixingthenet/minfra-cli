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
