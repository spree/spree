source 'http://rubygems.org'

gem 'rake', '~> 0.9.2'
#only required until 3.1 is released
gem "rails", :git => "git://github.com/rails/rails.git", :branch => "3-1-stable"
gem "require_relative"

# Asset template engines
gem 'json'
gem 'sass'
gem 'coffee-script'
gem 'uglifier'

group :test do
  gem 'rspec-rails', '= 2.6.1'
  gem 'factory_girl', '= 1.3.3'
  gem 'factory_girl_rails', '= 1.0.1'
  gem 'rcov'
  gem 'faker'
end

group :cucumber do
  gem 'cucumber-rails', '1.0.0'
  gem 'database_cleaner', '= 0.6.7'
  gem 'nokogiri'
  gem 'capybara', '1.0.0'
  gem 'factory_girl', '= 1.3.3'
  gem 'factory_girl_rails', '= 1.0.1'
  gem 'faker'
  gem 'launchy'

end

if RUBY_VERSION < "1.9"
  gem "ruby-debug"
else
  gem "ruby-debug19"
end

#root
