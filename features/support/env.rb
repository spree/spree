ENV['RAILS_ENV'] ||= 'cucumber'

require File.expand_path('../spec/dummy/config/environment', FEATURES_PATH)

# sometimes tests fail randomly because cache is not refreshed, fixed that
Spree::Config
require 'bundler'
Bundler.setup(:cucumber)

Rails.env = 'test'
require 'cucumber/formatter/unicode' # Remove this line if you don't want Cucumber Unicode support
Rails.env = 'cucumber'
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

Capybara.server_boot_timeout = 50

# How to clean your database when transactions are turned off. See
# http://github.com/bmabey/database_cleaner for more info.
require 'database_cleaner'
require 'database_cleaner/cucumber'

require 'spree/core/testing_support/factories'

# clean database before tests run
DatabaseCleaner.strategy = :truncation
DatabaseCleaner.clean

Capybara.save_and_open_page_path = File.join(Rails.root, 'tmp')

# load the rest of files for support and step definitions
directories = [ File.join(FEATURES_PATH, '../../features/support'),
                File.join(FEATURES_PATH, '../../features/step_definitions') ]

files = directories.map do |dir|
  Dir["#{dir}/**/*.rb"]
end.flatten.uniq

files.each do |path|
  if path !~ /env.rb$/
    fp = File.expand_path(path)
    #puts fp
    load(fp)
  end
end

DatabaseCleaner.strategy = :transaction

# call this method to see how factory_girl defines all the step definitions
# it helps in debugging when factory_girl step definition does not work
def factory_definitions_debugger
  Factory.factories.values.each do |factory|
    puts factory..model_name.human.pluralize
    if factory.build_class.respond_to?(:columns)
      factory.build_class.columns.each do |column|
        human_column_name = column.name.downcase.gsub('_', ' ')
        puts "an? #{factory.model_name.human} exists with an? #{human_column_name} of "
      end
    end
  end
end

#factory_definitions_debugger

require 'factory_girl/step_definitions'
