# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner'
require 'spree/core/testing_support/factories'
require 'spree/core/testing_support/env'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

# load default data for tests
require 'active_record/fixtures'

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.include Spree::Core::Engine.routes.url_helpers,
    :example_group => {
      :file_path => /\bspec\/requests\//
    }

  config.include Devise::TestHelpers, :type => :controller
  config.include Rack::Test::Methods, :type => :request
end

def api_login(user)
  authorize user.authentication_token, "X"
end

shared_examples_for "status ok" do
  it "should return status 200" do
    last_response.status.should == 200
  end
end

shared_examples_for "unauthorized" do
  it "should return status 401" do
    last_response.status.should == 401
  end
end
