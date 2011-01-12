source 'http://rubygems.org'

gem 'sqlite3-ruby', :require => 'sqlite3'

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
