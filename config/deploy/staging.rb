# No Elastic IP — this app's own public IP, which changes if the instance is
# ever stopped and restarted (accepted trade-off, decided when provisioning
# the EC2 instance). Update this if that ever happens.
server "3.86.9.94", user: "deploy", roles: %w[app db web]

set :stage, :staging
set :rails_env, "staging"
set :branch, "main"
