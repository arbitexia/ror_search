# config valid only for current version of Capistrano
lock '3.6.1'

set :application, 'sanction_search'
set :repo_url, 'git@github.com:Sanction-Search/sanctionsearch.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/home/ubuntu/sanction-search'
# set :deploy_to, '/home/deploy/sanction-search'

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'db/oig.db', 'db/sam.db', 'db/dhh.db', 'db/dhsar.db', 'db/msmedicaid.db', 'db/txoig.db',
       'db/laadra.db'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "db"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# assumes one web role
namespace :logs do
  task :app do
    on roles(:app) do
      execute "tail -n 100 -f #{shared_path}/log/unicorn.*.log #{shared_path}/log/production.log*"
    end
  end

  task :sidekiq do
    on roles(:sidekiq) do
      execute "tail -n 100 -f #{shared_path}/log/sidekiq.log"
    end
  end
end

after 'deploy:publishing', 'deploy:restart'
after 'deploy:restart', 'sidekiq:restart'
