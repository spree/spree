# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner'
require 'spree_core/testing_support/factories'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

# load default data for tests
require 'active_record/fixtures'
fixtures_dir = File.expand_path('../../../core/db/default', __FILE__)
ActiveRecord::Fixtures.create_fixtures(fixtures_dir, ['countries', 'zones', 'zone_members', 'states', 'roles'])

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
  #config.use_transactional_fixtures = true

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.include SpreeApi::Engine.routes.url_helpers,
    :example_group => {
      :file_path => /\bspec\/controllers\//
    }

  config.include Devise::TestHelpers, :type => :controller
  config.include Rack::Test::Methods
end

def api_login(user)
  #post_via_redirect user_session_path, 'user[email]' => user.email, 'user[password]' => user.password
  authorize user.authentication_token, "X"
end
