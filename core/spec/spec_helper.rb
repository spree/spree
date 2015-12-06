require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.infect(__dir__)

if ENV.key?('CHECK_TRANSLATIONS')
  require 'spree/testing_support/i18n'
end

require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  config.before :each do
    Rails.cache.clear
    reset_spree_preferences
  end

  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::Preferences

  # Clean out the database state before the tests run
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  # Test the factories
  config.before(:suite) do
    FactoryValidation.call
  end

  # Wrap all db isolated tests in a transaction
  config.around do |example|
    DatabaseCleaner.cleaning(&example)
  end

  config.around do |example|
    Timeout.timeout(40, &example)
  end
end
