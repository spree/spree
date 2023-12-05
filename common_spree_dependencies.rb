# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

%w[
  actionmailer actionpack actionview activejob activemodel activerecord
  activestorage activesupport railties
].each do |rails_gem|
  gem rails_gem, ENV.fetch('RAILS_VERSION', '~> 7.1.0'), require: false
end

platforms :jruby do
  gem 'jruby-openssl'
end

platforms :ruby do
  if ENV['DB'] == 'mysql'
    gem 'mysql2'
  else
    gem 'pg', '~> 1.1'
  end
end

gem 'sprockets-rails', '>= 2.0.0'

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'capybara-select-2'
  gem 'database_cleaner-active_record'
  gem 'email_spec'
  gem 'factory_bot_rails', '~> 6.2.0'
  gem 'multi_json'
  gem 'rspec-activemodel-mocks'
  gem 'rspec-rails'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'rswag-specs'
  gem 'jsonapi-rspec'
  gem 'simplecov'
  gem 'webmock'
  gem 'timecop'
  gem 'rails-controller-testing'
end

group :test, :development do
  gem 'awesome_print'
  gem 'brakeman'
  gem 'gem-release'
  gem 'i18n-tasks'
  gem 'redis'
  gem 'rubocop', '~> 1.0', require: false
  gem 'rubocop-rspec', require: false
  gem 'pry-byebug'
  gem 'webdrivers', '~> 4.1'
  gem 'puma'
  gem 'ffaker'
end

group :development do
  # gem 'github_fast_changelog'
  gem 'solargraph'
end
