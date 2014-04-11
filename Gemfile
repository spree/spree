source 'https://rubygems.org'

# Provides basic authentication functionality for testing parts of your engine
gem 'spree', git: 'https://github.com/spree/spree', branch: 'master'
gem 'spree_auth_devise', git: 'https://github.com/spree/spree_auth_devise', branch: 'master'

platforms :ruby do
  gem 'sqlite3'
end

gem 'coffee-rails', '~> 4.0.0'
gem 'sass-rails', '~> 4.0.0'

group :test do
  gem 'capybara', '~> 2.1'
  gem 'database_cleaner', '~> 1.0.1'
  gem 'factory_girl_rails', '~> 4.4.0'
  gem 'launchy'
  gem 'pry'
  gem 'rspec-rails', '~> 2.14.0'
  gem 'selenium-webdriver', '~> 2.35'
  gem 'simplecov'
  gem 'webmock', '1.8.11'
  gem 'poltergeist', '1.5.0'
end

gemspec
