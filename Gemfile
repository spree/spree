source 'http://rubygems.org'

gem "spree", :path => File.dirname(__FILE__)

# gem 'mysql'
gem 'sqlite3-ruby'
gem 'ruby-debug' if RUBY_VERSION.to_f < 1.9
gem "rdoc",  "2.2"

gemspec

group :test do
  gem 'rspec-rails', '~> 2.1.0'
  gem 'factory_girl_rails'
end

group :cucumber do
  gem 'cucumber-rails'
  gem 'capybara'
  gem 'launchy'
  gem 'nokogiri'
  gem 'database_cleaner', '~> 0.5.2'
  gem 'fabrication'
end
