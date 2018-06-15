# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'coffee-rails'
gem 'sass-rails'
gem 'sqlite3', platforms: [:ruby, :mingw, :mswin, :x64_mingw]
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
gem 'doorkeeper'

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

platforms :ruby do
  gem 'mysql2'
  gem 'pg', '~> 0.18'
end

group :test do
  gem 'capybara', '~> 2.16'
  gem 'capybara-screenshot', '~> 1.0'
  gem 'database_cleaner', '~> 1.3'
  gem 'email_spec'
  gem 'factory_bot_rails', '~> 4.8'
  gem 'launchy'
  gem 'rspec-activemodel-mocks', '~> 1.0'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails', '~> 3.7.2'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'jsonapi-rspec'
  gem 'simplecov'
  gem 'webmock', '~> 3.0.1'
  gem 'selenium-webdriver'
  gem 'chromedriver-helper'
  gem 'timecop'
  gem 'rails-controller-testing'
end

group :test, :development do
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'pry-byebug'
end
