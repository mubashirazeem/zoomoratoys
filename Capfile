# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# Load the SCM plugin
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

require "capistrano/rails"
require "capistrano/passenger"
require "capistrano/rbenv"

set :rbenv_type, :user
set :rbenv_ruby, "3.3.5"

# Loads custom tasks from `lib/capistrano/tasks` if any are added later.
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
