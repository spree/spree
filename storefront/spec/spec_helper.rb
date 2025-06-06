if ENV['COVERAGE']
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Libraries', 'lib/spree'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/generators/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/storefront" if ENV['COVERAGE_DIR']
  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'


begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
  exit
end

require 'rspec/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'database_cleaner/active_record'
require 'ffaker'

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/storefront/testing_support/capybara_utils'
require 'spree/storefront/testing_support/cart_utils'
require 'spree/testing_support/capybara_config'
require 'spree/testing_support/rspec_retry_config'
require 'spree/testing_support/image_helpers'

require 'spree/core/controller_helpers/strong_parameters'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'doc'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.before(:suite) do
    Capybara.match = :smart
    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_max_wait_time = 10
    Capybara.raise_server_errors = false
    # Clean out the database state before the tests run
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.before(:each) do
    Spree::Webhooks.disabled = true
    reset_spree_preferences
  end

  config.include FactoryBot::Syntax::Methods

  config.include Spree::Storefront::TestingSupport::CapybaraUtils
  config.include Spree::Storefront::TestingSupport::CartUtils
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::ImageHelpers

  config.include Spree::Core::ControllerHelpers::StrongParameters, type: :controller

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :feature

  config.order = :random
  Kernel.srand config.seed

  Capybara.server_port = 3000
  Capybara.test_id = 'data-test-id'

  config.filter_run_including focus: true unless ENV['CI']
  config.run_all_when_everything_filtered = true
end
