# Elastic IP, allocated once the EC2 instance exists (see the AWS production
# deploy runbook, Part 2.3) — unlike staging, production gets a real Elastic
# IP so DNS never silently breaks on a reboot.
server "REPLACE_WITH_ELASTIC_IP", user: "deploy", roles: %w[app db web]

set :stage, :production
set :rails_env, "production"
set :branch, "main"

# Overrides config/deploy.rb's shared ssh_options, which points at staging's
# key — production must never be reachable with the staging key.
set :ssh_options, forward_agent: true, keys: %w[~/.ssh/zoomora-production.pem]
