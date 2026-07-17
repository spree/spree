if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.root(ENV.fetch('GITHUB_WORKSPACE', File.expand_path('../../..', __dir__)))
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  SimpleCov.start 'rails' do
    group 'Finders', 'app/finders'
    group 'Mailers', 'app/mailers'
    group 'Paginators', 'app/paginators'
    group 'Services', 'app/services'
    group 'Sorters', 'app/sorters'
    group 'Validators', 'app/validators'
    group 'Libraries', 'lib/spree'

    skip '/app/assets/'
    skip '/app/javascript/'
    skip '/app/views/'
    skip '/bin/'
    skip '/config/'
    skip '/db/'
    skip '/lib/generators/'
    skip '/lib/spree/testing_support/'
    skip '/lib/tasks/'
    skip '/script/'
    skip '/spec/'
    skip '/vendor/'

    # CI_SHARD distinguishes runners; TEST_ENV_NUMBER distinguishes the parallel
    # rspec processes within a runner — both are needed so concurrent processes
    # don't clobber each other's coverage report.
    suffix = [ENV.fetch('CI_SHARD', '1'), ENV['TEST_ENV_NUMBER']].compact.reject(&:empty?).join('_')
    if ENV['COVERAGE_DIR']
      coverage_dir "#{ENV['COVERAGE_DIR']}/core_#{suffix}"
    end
    command_name "core_shard_#{suffix}"
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
require 'shoulda-matchers'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

require 'spree/testing_support/i18n' if ENV['CHECK_TRANSLATIONS']

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/metadata'
require 'spree/testing_support/lifecycle_events'
require 'spree/testing_support/preferences'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/kernel'
require 'spree/testing_support/rspec_retry_config'
require 'spree/testing_support/next_instance_of'

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

  config.before(:suite) do
    Spree::Events.disable!
    # Clean out the database state before the tests run
    DatabaseCleaner.clean_with(:truncation)
  end

  # Re-enable events for specs that need them
  # Also re-activate subscribers in case another spec called Events.reset!
  config.around(:each, events: true) do |example|
    Spree::Events.enable do
      Spree::Events.activate!
      example.run
    end
  end

  config.before(:each) do
    reset_spree_preferences
    Spree::Current.reset
  end

  config.include FactoryBot::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::Kernel

  config.order = :random
  Kernel.srand config.seed
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
