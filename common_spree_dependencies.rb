# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

platforms :ruby do
  gem 'mysql2'
  gem 'pg'
end

gem 'sqlite3', platforms: [:ruby, :mingw, :mswin, :x64_mingw]

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

gem 'coffee-rails', '~> 4.0.0'
gem 'sass-rails', '~> 5.0.0.beta1'

gem 'paranoia', github: 'huoxito/paranoia', branch: 'rails-4.2'
gem 'state_machine', github: 'huoxito/state_machine', branch: 'spree-rails4.2-upgrade'

group :test do
  gem 'capybara', '~> 2.4'
  gem 'database_cleaner', '~> 1.3'
  gem 'email_spec'
  gem 'factory_girl_rails', '~> 4.5.0'
  gem 'launchy'
  gem 'rspec-activemodel-mocks'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails', '~> 3.1.0'
  gem 'simplecov'
  gem 'webmock', '1.8.11'
  gem 'poltergeist', '1.5.0'
  gem 'timecop'
  gem 'with_model'
end

group :test, :development do
  gem 'rubocop', require: false

  platforms :ruby_19 do
    gem 'pry-debugger'
  end
  platforms :ruby_20, :ruby_21 do
    gem 'pry-byebug'
  end
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
