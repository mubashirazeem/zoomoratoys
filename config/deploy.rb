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
#
# keys: is set explicitly here rather than relying on a personal ~/.ssh/config
# alias, since Capistrano connects using the literal host from `server` below
# (an IP, not an alias) — SSH's own alias-based IdentityFile matching never
# applies to a bare IP, so without this, authentication silently falls back
# to whatever default keys happen to be present.
set :ssh_options, forward_agent: true, keys: %w[~/.ssh/zoomora-staging.pem]

# capistrano-passenger's default restart task runs `passenger-config
# restart-app`, which requires reading Passenger's instance registry — but
# that registry is owned by root (Nginx starts as root via systemd, with no
# separate lower-privileged worker user configured), while Capistrano runs
# this as the deploy user, which can't read root's registry. Redefined here
# to use Passenger's original, permission-agnostic restart signal instead:
# touching tmp/restart.txt, which Passenger checks on every request
# regardless of which user owns the running instance.
namespace :passenger do
  Rake::Task["passenger:restart"].clear_actions
  task :restart do
    on roles(:app) do
      execute :touch, release_path.join("tmp/restart.txt")
    end
  end
end

# public/sitemap*.xml.gz is deliberately gitignored (not source — see
# .gitignore) and public/ isn't in linked_dirs, so without this the sitemap
# Google is told about at /sitemap.xml.gz (see public/robots.txt) never
# actually exists on a deployed release. Regenerate fresh on every deploy
# instead of trying to carry a stale copy forward across releases.
namespace :sitemap do
  desc "Regenerate the sitemap for the just-deployed release"
  task :refresh do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "sitemap:refresh:no_ping"
        end
      end
    end
  end
end
after "deploy:publishing", "sitemap:refresh"
