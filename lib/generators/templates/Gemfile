source 'http://rubygems.org'

gem 'sqlite3-ruby', :require => 'sqlite3'

group :test do
  gem 'rspec-rails', '= 2.4.1'
  gem 'factory_girl_rails'
  gem 'rcov'
  gem 'shoulda'
  gem 'faker'
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
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'launchy'

  if RUBY_VERSION < "1.9"
    gem "ruby-debug"
  else
    gem "ruby-debug19"
  end
end
