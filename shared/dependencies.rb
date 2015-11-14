# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

platforms :jruby do
  gem 'jruby-openssl'
end

group :test do
  gem 'capybara',         '~> 2.4'
  gem 'database_cleaner', '~> 1.3'
  gem 'email_spec'
  gem 'factory_girl_rails', '~> 4.5.0'
  gem 'rspec-activemodel-mocks'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails', '~> 3.3.3'
  gem 'simplecov'
  gem 'poltergeist', '1.5.0'
  gem 'timecop'
  gem 'with_model'
end

group :test, :development do
  platforms :ruby_19 do
    gem 'pry-debugger'
  end
  platforms :ruby_20, :ruby_21 do
    gem 'pry-byebug'
  end
  gem 'mutant-rspec', '~> 0.8.2'
end
