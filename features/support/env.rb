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

Zone.class_eval do
  def self.global
    find_by_name("GlobalZone") || Factory(:global_zone)
  end
end

# use the factory girl step definitions
require 'factory_girl'

Dir["#{File.dirname(__FILE__)}/../../core/spec/factories/**"].each do |f|
  fp =  File.expand_path(f)
  require fp
end

# clean database before tests run
DatabaseCleaner.strategy = :truncation
DatabaseCleaner.clean

Capybara.save_and_open_page_path = File.join(Rails.root, "tmp")

# load the rest of files for support and step definitions
directories = [ File.join(FEATURES_PATH, '../../features/support'),
               File.join(FEATURES_PATH, '../../features/step_definitions') ]

files = directories.map do |dir|
  Dir["#{dir}/**/*"]
end.flatten.uniq

files.each do |path|
  if path !~ /env.rb$/
    fp = File.expand_path(path)
    load(fp)
  end
end


DatabaseCleaner.strategy = :transaction
#Factory.factories.values.each { |factory| puts factory.human_name.pluralize }
require 'factory_girl/step_definitions'
