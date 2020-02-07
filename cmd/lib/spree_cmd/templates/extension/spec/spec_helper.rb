# Run Coverage report
require 'simplecov'
SimpleCov.start do
  add_filter 'spec/dummy'
  add_group 'Controllers', 'app/controllers'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Models', 'app/models'
  add_group 'Views', 'app/views'
  add_group 'Services', 'app/services'
  add_group 'Libraries', 'lib/spree'
end

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb', __FILE__)

require 'rspec/rails'
require 'ffaker'
require 'pry'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }

# Requires factories and other useful helpers defined in spree_core.
require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/caching'

# API v2 helpers
require 'spree/api/testing_support/v2/base'
require 'spree/api/testing_support/v2/current_order'

RSpec.configure do |config|
  # Infer an example group's spec type from the file location.
  config.infer_spec_type_from_file_location!

  # == URL Helpers
  #
  # Allows access to Spree's routes in specs:
  #
  # visit spree.admin_path
  # current_path.should eql(spree.products_path)
  config.include Spree::TestingSupport::UrlHelpers

  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec
  config.color = true
  config.default_formatter = 'doc'

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Capybara javascript drivers require transactional fixtures set to false, and we use DatabaseCleaner
  # to cleanup after each test instead.  Without transactional fixtures set to false the records created
  # to setup a test will be unavailable to the browser, which runs under a separate server instance.
  config.use_transactional_fixtures = false

  config.fail_fast = ENV['FAIL_FAST'] || false
  config.order = 'random'

  config.before :each do
    Rails.cache.clear
    reset_spree_preferences do |config|
      # config.my_custom_preference = 10
    end
  end

  config.before(:each, type: :controller) do
    @request.env['devise.mapping'] = Devise.mappings[:spree_user]
  end

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::Flash

  config.include Devise::TestHelpers, type: :controller if defined?(Devise)

  if defined?(Warden)
    config.include Warden::Test::Helpers
    config.before :suite do
      Warden.test_mode!
    end
  end
end
