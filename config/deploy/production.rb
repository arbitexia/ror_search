server '18.220.29.50', user: 'ubuntu', roles: %w[app db web sidekiq_local]
server '18.216.4.52', user: 'ubuntu', roles: %w[sidekiq_scheduler sidekiq_all]
server '3.82.204.61', user: 'ubuntu', roles: %w[sidekiq_scheduler sidekiq_all]
set :nginx_server_name, '18.220.29.50 sanctionsearch.net www.sanctionsearch.net'

set :sidekiq_role, %i[sidekiq_local sidekiq_all]
# sidekiq_local only runs the first process with the hostname-specific queue
# this allows us to ensure that the batch jobs that read local data files only run on the app instance

# these options totally override sidekiq.yml
set :sidekiq_options_per_process, ['-q `hostname`', '-q default', '-q reports', '-q mailers', '-q mailers']
set :sidekiq_local_processes, 1
set :sidekiq_all_processes, 5
set :sidekiq_concurrency, 1

set :ssh_options, forward_agent: true,
                  auth_methods: ['publickey'],
                  keys: ['SanctionSearch.pem']
