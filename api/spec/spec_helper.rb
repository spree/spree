if ENV['COVERAGE']
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Serializers', 'app/serializers'
    add_group 'Libraries', 'lib/spree'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/spree/api/testing_support/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/api_"+ ENV.fetch('CIRCLE_NODE_INDEX', 0) if ENV['COVERAGE_DIR']
    command_name "test_" + ENV.fetch('CIRCLE_NODE_INDEX', 0)

  end
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
  exit
end

require 'rspec/rails'
require 'database_cleaner/active_record'
require 'ffaker'
require 'webmock/rspec'
require 'i18n/tasks'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/preferences'
require 'spree/testing_support/image_helpers'
require 'spree/testing_support/next_instance_of'
require 'spree/testing_support/rspec_retry_config'

require 'spree/api/testing_support/serializers'
require 'spree/api/testing_support/v2/base'
require 'spree/api/testing_support/v2/current_order'
require 'spree/api/testing_support/v2/platform_contexts'
require 'spree/api/testing_support/v2/serializers_params'
require 'spree/api/testing_support/factories'

def json_response
  case body = JSON.parse(response.body)
  when Hash
    body.with_indifferent_access
  when Array
    body
  end
end

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [/gems\/activesupport/, /gems\/actionpack/, /gems\/rspec/]
  config.color = true
  config.default_formatter = 'doc'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = true

  config.include JSONAPI::RSpec
  config.include FactoryBot::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::ImageHelpers

  config.before(:suite) do
    Spree::Events.disable!
    # Clean out the database state before the tests run
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do
    reset_spree_preferences

    # Request specs to paths with ?locale=xx don't reset the locale afterwards
    # Some tests assume that the current locale is :en, so we ensure it here
    I18n.locale = :en

    # Reset Spree::Current to avoid stale memoized values between tests
    Spree::Current.reset
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.order = :random
end
