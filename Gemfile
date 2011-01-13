source 'http://rubygems.org'

gem "spree", :path => File.dirname(__FILE__)

# gem 'mysql'
gem 'sqlite3-ruby'
gem 'ruby-debug' if RUBY_VERSION.to_f < 1.9
gem "rdoc",  "2.2"

gemspec

group :test do
  gem 'rspec-rails', '= 2.4.1'
  gem 'factory_girl_rails'
  gem 'fabrication'
  gem 'rcov'
  gem 'shoulda'
  if RUBY_VERSION < "1.9"
    gem "ruby-debug"
  else
    gem "ruby-debug19"
  end
end

group :cucumber do
  gem 'cucumber-rails'
  gem 'database_cleaner', '~> 0.5.2'
  gem 'nokogiri'
  gem 'capybara'
  gem 'fabrication'
  gem 'factory_girl_rails'

  if RUBY_VERSION < "1.9"
    gem "ruby-debug"
  else
    gem "ruby-debug19"
  end
end
