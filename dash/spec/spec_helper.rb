# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner'
require 'spree/core/url_helpers'
require 'ffaker'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'spree/core/testing_support/factories'
require 'spree/core/testing_support/env'

require 'active_record/fixtures'
fixtures_dir = File.expand_path('../../../core/db/default', __FILE__)
ActiveRecord::Fixtures.create_fixtures(fixtures_dir, ['spree/countries', 'spree/zones', 'spree/zone_members', 'spree/states', 'spree/roles'])

RSpec.configure do |config|
  config.mock_with :rspec

  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation, { :except => ['spree_countries', 'spree_zones', 'spree_zone_members', 'spree_states', 'spree_roles'] }
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.include FactoryGirl::Syntax::Methods
  config.include Spree::Core::UrlHelpers

  config.include Rack::Test::Methods, :type => :requests
end
