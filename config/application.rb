require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SanctionSearch
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += %W[#{config.root}/app/searchers]
    config.autoload_paths += %W[#{config.root}/app/integrations]

    config.cache_store = :redis_store, 'redis://localhost:6379/0/cache'
    config.active_job.queue_adapter = :sidekiq

    config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :local

    config.action_mailer.delivery_job = 'ActionMailer::MailDeliveryJob'
  end
end
