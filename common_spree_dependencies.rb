# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'coffee-rails'
gem 'sass-rails'
gem 'sqlite3', platforms: [:ruby, :mingw, :mswin, :x64_mingw]
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

platforms :ruby do
  gem 'mysql2', '~> 0.4.10'
  gem 'pg', '~> 0.18'
end

group :test do
  gem 'bootstrap-sass', '>= 3.3.5.1', '< 3.4'
  gem 'capybara', '~> 2.4'
  gem 'capybara-screenshot', '~> 1.0'
  gem 'canonical-rails', '~> 0.2.0'
  gem 'database_cleaner', '~> 1.3'
  gem 'email_spec'
  gem 'factory_bot_rails', '~> 4.8'
  gem 'jquery-rails', '~> 4.3'
  gem 'jquery-ui-rails', '~> 6.0.1'
  gem 'launchy'
  gem 'rabl', '~> 0.13.1'
  gem 'rack-test', '0.7.0'
  gem 'rails-controller-testing'
  gem 'rspec-activemodel-mocks', '~> 1.0'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails', '~> 3.7.2'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'select2-rails', '3.5.9.1' # 3.5.9.2 breaks several specs
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'webmock', '~> 3.0.1'
  gem 'timecop'
  gem 'versioncake', '~> 3.3.0'
  gem 'with_model'
end
