Sidekiq.configure_server do |config|
  schedule_file = 'config/schedule.yml'
  config.redis =  if Rails.env.production?
                    if `hostname` == "ip-172-31-88-225\n"
                      { url: 'redis://18.220.29.50:6379/0' }
                    else
                      { url: 'redis://172.31.27.237:6379/0' }
                    end
                  else
                    { url: 'redis://127.0.0.1:6379/0' }
                  end

  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if Rails.env.development? || Rails.env.production?

  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::RetryJobs, max_retries: 0
  end
end

Sidekiq.options[:poll_interval] = 10
