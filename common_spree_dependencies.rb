# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

platforms :ruby do
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3'
end

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

gem 'coffee-rails', '~> 4.0.0'
gem 'sass-rails', '~> 4.0.2'

group :test do
  gem 'capybara', '~> 2.1'
  gem 'database_cleaner', '~> 1.0.1'
  gem 'email_spec', '1.4.0'
  gem 'factory_girl_rails', '~> 4.4.0'
  gem 'launchy'
  gem 'pry'
  gem 'rspec-rails', '~> 2.14.0'
  gem 'simplecov'
  gem 'webmock', '1.8.11'
  gem 'poltergeist', '1.5.0'
end

gem 'polyamorous', github: 'huoxito/polyamorous', branch: 'drop-graft'
gem 'ransack', github: 'huoxito/ransack', branch: 'rails-v4.1.0'
gem 'paranoia', github: 'huoxito/paranoia', branch: 'rails-4.1.0.beta1'

gem 'state_machine', github: 'lukeroberts1990/state_machine'
