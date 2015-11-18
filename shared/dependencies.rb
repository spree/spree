# By placing all of Spree's shared dependencies in this file and then loading
# it for each component's Gemfile, we can be sure that we're only testing just
# the one component of Spree.
source 'https://rubygems.org'

group :test do
  gem 'capybara',                  '~> 2.5.0'
  gem 'database_cleaner',          '~> 1.5.1'
  gem 'devtools',                  '~> 0.1.2', git: 'https://github.com/mbj/devtools.git'
  gem 'email_spec',                '~> 1.6.0'
  gem 'factory_girl_rails',        '~> 4.5.0'
  gem 'ffaker',                    '~> 2.1.0'
  gem 'rspec-activemodel-mocks',   '~> 1.0.2'
  gem 'rspec-collection_matchers', '~> 1.1.2'
  gem 'rspec-rails',               '~> 3.4.0'
  gem 'timecop',                   '~> 0.8.0'
  gem 'poltergeist',               '~> 1.8.0'
  gem 'with_model',                '~> 1.2.1'
end
