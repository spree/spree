if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.root(ENV.fetch('GITHUB_WORKSPACE', File.expand_path('../../..', __dir__)))
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  SimpleCov.start 'rails' do
    add_group 'Models', 'app/models'
    add_group 'Services', 'app/services'
    add_group 'Presenters', 'app/presenters'
    add_group 'Jobs', 'app/jobs'

    add_filter '/bin/'
    add_filter '/config/'
    add_filter '/db/'
    add_filter '/lib/generators/'
    add_filter '/lib/spree_stripe/testing_support/'
    add_filter '/lib/tasks/'
    add_filter '/spec/'

    suffix = [ENV.fetch('CI_SHARD', '1'), ENV['TEST_ENV_NUMBER']].compact.reject(&:empty?).join('_')
    coverage_dir "#{ENV['COVERAGE_DIR']}/stripe_#{suffix}" if ENV['COVERAGE_DIR']
    command_name "stripe_shard_#{suffix}"
  end
end

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

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/preferences'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/kernel'
require 'spree/testing_support/rspec_retry_config'
require 'spree_stripe/factories'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'progress'
  config.fail_fast = ENV['FAIL_FAST'] || false
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = true

  config.before(:suite) do
    Spree::Events.disable!
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each, events: true) do |example|
    Spree::Events.enable { example.run }
  end

  config.before(:each) do
    reset_spree_preferences
    I18n.locale = :en
  end

  config.include FactoryBot::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::Kernel

  config.order = :random
  Kernel.srand config.seed
end
