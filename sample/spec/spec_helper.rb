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
  config.default_formatter = 'doc'
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
    begin
      Rails.cache.clear
      reset_spree_preferences
    rescue Errno::ENOTEMPTY
    end
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:suite) do
    DatabaseCleaner.start
  end

  config.append_after do
    DatabaseCleaner.clean
  end
end
