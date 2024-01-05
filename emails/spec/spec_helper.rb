if ENV['COVERAGE']
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Models', 'app/models'
    add_group 'Mailers', 'app/mailers'
    add_group 'Helpers', 'app/helpers'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/spree/testing_support/'
    add_filter '/lib/generators/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/emails_" + ENV.fetch('CIRCLE_NODE_INDEX', 0) if ENV['COVERAGE_DIR']
    command_name "test_" + ENV.fetch('CIRCLE_NODE_INDEX', 0)


  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
end

require 'rspec/rails'
require 'database_cleaner/active_record'
require 'ffaker'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

require 'spree/testing_support/i18n' if ENV['CHECK_TRANSLATIONS']

require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/kernel'
require 'spree/testing_support/rspec_retry_config'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'doc'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.fixture_path = File.join(__dir__, 'fixtures')
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.before do
    Rails.cache.clear
    WebMock.disable!
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
    reset_spree_preferences

    country = create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US', states_required: true)

    create(:store, default_country: country, default: true)
  end

  config.include FactoryBot::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::Kernel

  # Clean out the database state before the tests run
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.order = :random
  Kernel.srand config.seed
end
