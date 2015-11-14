# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

platforms :jruby do
  gem 'jruby-openssl'
end

group :test do
  gem 'capybara',                  '~> 2.4'
  gem 'database_cleaner',          '~> 1.3'
  gem 'email_spec',                '~> 1.6'
  gem 'factory_girl_rails',        '~> 4.5.0'
  gem 'ffaker',                    '~> 1.16'
  gem 'mutant-rspec',              '~> 0.8.2'
  gem 'rspec-activemodel-mocks',   '~> 1.0.2'
  gem 'rspec-collection_matchers', '~> 1.1.2'
  gem 'rspec-its',                 '~> 1.2.0'
  gem 'rspec-rails',               '~> 3.3.3'
  gem 'simplecov',                 '~> 0.10.0'
  gem 'timecop',                   '~> 0.8.0'
  gem 'poltergeist',               '=  1.5.0'
  gem 'with_model',                '~> 1.2.1'
end

group :test, :development do
  platforms :ruby_19 do
    gem 'pry-debugger'
  end
  platforms :ruby_20, :ruby_21 do
    gem 'pry-byebug'
  end
end
