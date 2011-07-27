source 'http://rubygems.org'

gem "spree", :path => File.dirname(__FILE__)

gem 'sqlite3'

gemspec

group :test do
  gem 'rspec-rails', '= 2.6.1'
  gem 'factory_girl_rails'
  gem 'factory_girl', '= 1.3.3'
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
  gem 'database_cleaner', '= 0.6.7'
  gem 'capybara', '= 1.0.0'
  gem 'faker'
  gem 'launchy'
  gem 'selenium-webdriver', '~>0.2.2' # temporarily needed until next capybara release

  if RUBY_VERSION < "1.9"
    gem "ruby-debug"
  else
    gem "ruby-debug19"
  end
end
