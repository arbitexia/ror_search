ruby '2.7.3'

source 'https://rubygems.org'

# git_source(:github) do |repo_name|
#   repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
#   "https://github.com/#{repo_name}.git"
# end

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '6.0.3.1'
# Use sqlite3 as the database for Active Record
gem 'sqlite3'
# Use Puma as the app server
gem 'puma', '~> 3.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
gem 'select2-rails', '~> 4.0', '>= 4.0.3'
gem 'nokogiri', '1.11.0'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'database_cleaner'
  gem 'rspec-rails'
  gem 'simplecov'
end

# gem 'selenium-webdriver'
# gem 'capybara'

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'listen', '~> 3.0.5'
  gem 'web-console', '>= 3.3.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'foreman'
  gem 'rubocop'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem "better_errors"
end

group :production do
  gem 'unicorn'
end

gem 'pg'

# capistrano for deployment
gem 'capistrano', '3.6.1'
gem 'capistrano-bundler', '1.1.4'
gem 'capistrano-logrotate', '0.1.1'
gem 'capistrano-rails', '1.1.7'
gem 'capistrano-rails-console', require: false
gem 'capistrano-rvm', '0.1.2'
gem 'capistrano-sidekiq', '0.5.4'
gem 'capistrano-touch-linked-files'
gem 'capistrano-unicorn-nginx', github: 'griffithac/capistrano-unicorn-nginx', branch: 'systemd'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# to send emails via Mailgun API
gem 'mailgun_rails'

gem 'devise'
gem 'rest-client'
gem 'retries'
gem 'rolify'
gem 'will_paginate', '3.1.7'

gem 'rufus-scheduler', '3.2'

# background job backend for scheduled emails, analytics etc.
gem 'sidekiq', '~> 4.1'
gem 'sidekiq-cron'
gem 'sidekiq-failures'
gem 'sidekiq_monitor'
gem 'sinatra' # required for sidekiq web

gem 'redis-rails' # need this for redis cache store

# for generating report pdfs
gem 'docx_replace'
gem 'prawn'
gem 'rubyXL' # reading xlsx
gem 'wicked_pdf' # for rendering pdfs conveniently

gem 'dotenv-rails'

gem 'archive-zip'

gem 'autoprefixer-rails'

gem 'enumerize'
gem 'letter_opener', group: :development
gem 'ox'
gem 'devise_masquerade'
gem 'pundit'
gem 'rollbar'
gem 'annotate'