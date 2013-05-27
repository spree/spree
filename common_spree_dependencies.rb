# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'json'
gem 'multi_json'
gem 'mysql2'
gem 'pg'
gem 'sqlite3'

gem 'coffee-rails', '~> 4.0.0.rc1'
gem 'sass-rails', '~> 4.0.0.rc1'

group :test do
  gem 'capybara', '~> 1.1'
  gem 'database_cleaner', '~> 1.0.1'
  gem 'email_spec', '1.4.0'
  gem 'factory_girl_rails', '~> 4.2.1'
  gem 'ffaker'
  gem 'launchy'
  gem 'pry'
  gem 'rspec-rails', '~> 2.13.0'
  gem 'selenium-webdriver', '2.32.0'
  gem 'simplecov'
  gem 'webmock', '1.8.11'
end

gemspec
