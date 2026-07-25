lock "~> 3.19"

set :application, "zoomora_toys"
set :repo_url, "git@github.com:mubashirazeem/ZoomoraToys.git"

# Deploy to the deploy user's home directory on the target server.
set :deploy_to, "/home/deploy/zoomora_toys"

# Directories that must persist across releases — Active Storage's local-disk
# uploads (storage) most importantly, since a fresh release directory
# would otherwise start with zero uploaded product photos every deploy.
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "storage"

# Only keep the last 5 releases on disk to bound storage use on a small box.
set :keep_releases, 5

# Deploys using the operator's own already-authorized GitHub SSH key,
# forwarded transiently through the SSH connection during `cap deploy` — no
# separate deploy key to create or rotate on the server itself.
set :ssh_options, forward_agent: true
