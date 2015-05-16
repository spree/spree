if ENV["COVERAGE"]
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start do
    add_group 'Controllers', 'app/controllers'
    add_group 'Helpers', 'app/helpers'
    add_group 'Mailers', 'app/mailers'
    add_group 'Models', 'app/models'
    add_group 'Views', 'app/views'
    add_group 'Jobs', 'app/jobs'
    add_group 'Libraries', 'lib'
  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'

begin
  require File.expand_path("../dummy/config/environment", __FILE__)
rescue LoadError
  puts "Could not load dummy application. Please ensure you have run `bundle exec rake test_app`"
end

require 'rspec/rails'
require 'rspec/its'
require 'database_cleaner'
require 'ffaker'
require 'timeout'

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

if ENV["CHECK_TRANSLATIONS"]
  require "spree/testing_support/i18n"
end

require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  config.fixture_path = File.join(File.expand_path(File.dirname(__FILE__)), "fixtures")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.before :each do
    Rails.cache.clear
    reset_spree_preferences
  end

  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::Preferences

  config.fail_fast = ENV['FAIL_FAST'] || false

  # Clean out the database state before the tests run
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  # Test the factories
  config.before(:suite) do
    DatabaseCleaner.cleaning do
      factories = FactoryGirl.factories.reject do |factory|
        %i[
          customer_return_without_return_items
          global_zone
          stock_packer
          stock_package
          stock_package_fulfilled
        ].include?(factory.name)
      end
      FactoryGirl.lint(factories)
    end
  end

  # Wrap all db isolated tests in a transaction
  config.around(db: :isolate) do |example|
    DatabaseCleaner.cleaning(&example)
  end

  config.around do |example|
    Timeout.timeout(40, &example)
  end
end
