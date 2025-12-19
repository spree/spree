if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Libraries', 'lib/spree'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/generators/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/page_builder" if ENV['COVERAGE_DIR']
  end
end

ENV['RAILS_ENV'] ||= 'test'

begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
  exit
end

require 'rspec/rails'
require 'database_cleaner/active_record'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'ffaker'

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/url_helpers'

require 'spree/page_builder/testing_support/factories'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'doc'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!

  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::AuthorizationHelpers::Controller, type: :controller
end
