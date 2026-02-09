# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../dummy/config/environment', __FILE__)
require 'rspec/rails'
require 'ffaker'
require 'spree_sample'

require 'spree/testing_support/preferences'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'progress'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods

  config.order = :random
  Kernel.srand config.seed

  config.include Spree::TestingSupport::Preferences

  config.before do
    reset_spree_preferences
  end

  config.before(:suite) do
    Spree::Events.disable!
    DatabaseCleaner.clean_with(:truncation)
  end

  # Re-enable events for specs that need them
  config.around(:each, events: true) do |example|
    Spree::Events.enable { example.run }
  end
end
