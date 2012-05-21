# By placing all of Spree's shared dependencies in this file and then loading 
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'http://rubygems.org'

gem 'json'
gem 'sqlite3'
gem 'mysql2'
gem 'pg'
gem 'multi_json', "1.2.0"
# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "~> 3.2"
  gem 'coffee-rails', "~> 3.2"
end

group :test do
  gem 'guard'
  gem 'guard-rspec', '~> 0.5.0'
  gem 'rspec-rails', '~> 2.9.0'
  gem 'factory_girl_rails', '~> 1.7.0'
  gem 'email_spec', '~> 1.2.1'
  gem 'devise', '~> 2.0.4'

  gem 'ffaker'
  gem 'shoulda-matchers', '~> 1.0.0'
  gem 'capybara'
  gem 'selenium-webdriver', '2.20.0'
  gem 'database_cleaner', '0.7.1'
  gem 'launchy'
end

# platform :ruby_18 do
#   gem "ruby-debug"
# end

# platform :ruby_19 do
#   gem "ruby-debug19"
# end

gemspec


