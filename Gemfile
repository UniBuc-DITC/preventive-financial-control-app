# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.4'

gem 'rails', '~> 8.0'

gem 'rails-i18n', '~> 8.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use PostgreSQL as the database for Active Record
gem 'pg', '~> 1.5'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Better, more structured logging
gem 'lograge'

# Windows does not include zoneinfo files, so bundle the `tzinfo-data` gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Sass language support
gem 'dartsass-sprockets'

# JQuery library
gem 'jquery-rails'

# Bootstrap 5 UI library
gem 'bootstrap', '~> 5.3.2'

# Make Rails form elements use Bootstrap
gem 'bootstrap_form', '~> 5.4'

# Helper for querying the Microsoft Graph API
gem 'microsoft_graph', '>= 0.22'

# Authentication support
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
# Required for authenticating against the Microsoft Identity platform
gem 'omniauth-oauth2'

# Pagination support
gem 'will_paginate', '~> 4.0'
gem 'will_paginate-bootstrap-style'

# Excel export support
gem 'caxlsx'
gem 'caxlsx_rails'

# CSV I/O
gem 'csv'

# Excel import support
gem 'roo', '~> 2.10.0'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows]

  # Factory Bot makes it easy to create new objects with fake data
  gem 'factory_bot_rails'
end

group :development do
  # Automated linting and formatting
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-capybara', require: false

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Error page with more features for use in development
  gem 'better_errors'
  gem 'binding_of_caller'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem 'rack-mini-profiler'

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem 'spring'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'

  # Support for additional test results reporting formats
  gem 'minitest-reporters'

  # Support for test coverage reporting
  gem 'simplecov'
  gem 'simplecov-cobertura'
end

group :production do
  # Enable the Elastic Application Performance Monitoring agent for Ruby
  gem 'elastic-apm'
end
