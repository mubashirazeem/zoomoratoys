# The server line below uses a placeholder IP. A later, separate piece of
# work (AWS provisioning — out of scope for this plan) creates the real EC2
# instance and its Elastic IP. Nothing in this file works against a real
# server until REPLACE_WITH_STAGING_ELASTIC_IP is replaced with that real
# value.
server "REPLACE_WITH_STAGING_ELASTIC_IP", user: "deploy", roles: %w[app db web]

set :stage, :staging
set :rails_env, "staging"
set :branch, "main"
