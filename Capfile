# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'
require 'capistrano/unicorn_nginx'
require 'capistrano/rvm'
require 'capistrano/rails'
require 'capistrano/sidekiq'
require 'capistrano/logrotate'
require 'capistrano/rails/console'
require 'capistrano/touch-linked-files'

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
