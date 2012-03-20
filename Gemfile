source 'http://rubygems.org'

gem 'json'
gem 'sqlite3'
gem 'mysql2'
gem 'pg'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "~> 3.2"
  gem 'coffee-rails', "~> 3.2"
end

group :test do
  gem 'guard'
  gem 'guard-rspec', '~> 0.5.0'
  gem 'rspec-rails', '~> 2.8.0'
  gem 'factory_girl_rails', '~> 1.7.0'
  gem 'email_spec', '~> 1.2.1'

  platform :ruby_18 do
    gem 'rcov'
  end

  platform :ruby_19 do
    gem 'simplecov'
  end

  gem 'ffaker'
  gem 'shoulda-matchers', '~> 1.0.0'
  gem 'capybara'
  gem 'selenium-webdriver', '2.16.0'
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


