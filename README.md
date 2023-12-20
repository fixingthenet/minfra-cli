# minfra-cli

Is a KIND (k8s in docker) based development environment.


## Setup/Configuration/Global options

|Description | environment variable | project keys | global commandline arguments | hiera key|
|---|---|---|---|
| | MINFRA_NAME | | name |
| | MINFRA_PATH | | --minfra_path [PATH TO MINFRA_PROJECT] |
| | MINFRA_ENVIRONMENT | | -e [ENV] |
| | MINFRA_ARGV_FILE | | --minfra_argv_file [PATH TO A CSV FILE FILE] |
| | MINFRA_LOGGING_LEVEL | minfra.logging_level | |
| |  | minfra.hiera.env_path | |


## Expected hiera data

 * l("cluster.id"): the k8s name of the cluster
 













# Orchparty

It's a fork of the original orchparty. TBD: see

The base is an application

an application can have 
 * services
 * apply
 * environment
 * variables
 * configurations
 * secrets
