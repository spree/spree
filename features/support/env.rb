ENV["RAILS_ENV"] ||= "cucumber"

require File.expand_path("../spec/test_app/config/environment", FEATURES_PATH)

# sometimes tests fail randomly because cache is not refreshed, fixed that
Spree::Config.set(:foo => "bar")

require 'bundler'
Bundler.setup(:cucumber)

Rails.env = "test"
require 'cucumber/formatter/unicode' # Remove this line if you don't want Cucumber Unicode support
Rails.env = "cucumber"
require 'cucumber/rails/world'
require 'cucumber/web/tableish'
require 'cucumber/rails/rspec'

require 'capybara/rails'
require 'capybara/cucumber'
require 'capybara/session'
# Capybara defaults to XPath selectors rather than Webrat's default of CSS3. In
# order to ease the transition to Capybara we set the default here. If you'd
# prefer to use XPath just remove this line and adjust any selectors in your
# steps to use the XPath syntax.
Capybara.default_selector = :css

# How to clean your database when transactions are turned off. See
# http://github.com/bmabey/database_cleaner for more info.
require 'database_cleaner'
require 'database_cleaner/cucumber'

# clean database before tests run
DatabaseCleaner.strategy = :truncation
DatabaseCleaner.clean

Capybara.save_and_open_page_path = File.join(Rails.root, "tmp")

# load the rest of files for support and step definitions
directories = [File.join(FEATURES_PATH, '../../features/support'),
               File.join(FEATURES_PATH, 'support'),
               File.join(FEATURES_PATH, 'step_definitions'),
               File.join(FEATURES_PATH, '../../features/step_definitions')]

files = directories.map do |dir|
  Dir["#{dir}/**/*"]
end.flatten.uniq

files.each do |path|
  load(path) if path !~ /env.rb$/
end

# use the factory girl step definitions
require 'factory_girl'
require 'factory_girl/step_definitions'

DatabaseCleaner.strategy = :transaction
