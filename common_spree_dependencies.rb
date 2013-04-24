# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'json'
gem 'multi_json'
gem 'mysql2'
gem 'pg'
gem 'sqlite3'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails', '~> 3.2'
  gem 'sass-rails', '~> 3.2'
end

group :test do
  gem 'capybara', '~> 2.1.0'
  gem 'database_cleaner', '0.7.1'
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
