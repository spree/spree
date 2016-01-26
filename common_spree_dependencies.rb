# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'coffee-rails', '~> 4.0.0'
gem 'sass-rails', '~> 5.0.0'
gem 'sqlite3', platforms: [:ruby, :mingw, :mswin, :x64_mingw]
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

platforms :ruby do
  gem 'mysql2'
  gem 'pg'
end

group :test do
  gem 'capybara', '~> 2.4'
  gem 'capybara-screenshot', '~> 1.0.11'
  gem 'database_cleaner', '~> 1.3'
  gem 'email_spec'
  gem 'factory_girl_rails', '~> 4.5.0'
  gem 'launchy'
  gem 'rspec-activemodel-mocks', '~> 1.0.2'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails', '3.4.0'
  gem 'simplecov'
  gem 'webmock', '1.8.11'
  gem 'poltergeist', '1.6.0'
  gem 'timecop'
  gem 'with_model'
  gem 'mutant-rspec', '~> 0.8.0'
  gem 'shoulda-matchers', '~> 3.0'
  gem 'shoulda-callback-matchers', '~> 1.1.1'
end

group :test, :development do
  gem 'rubocop', require: false
  gem 'pry-byebug'
end
