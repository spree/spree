if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.root(ENV.fetch('GITHUB_WORKSPACE', File.expand_path('../../..', __dir__)))
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  SimpleCov.start 'rails' do
    add_group 'Models', 'app/models'
    add_group 'Services', 'app/services'
    add_filter '/bin/'
    add_filter '/lib/spree_avalara/testing_support/'
    add_filter '/spec/'

    suffix = [ENV.fetch('CI_SHARD', '1'), ENV['TEST_ENV_NUMBER']].compact.reject(&:empty?).join('_')
    coverage_dir "#{ENV['COVERAGE_DIR']}/avalara_#{suffix}" if ENV['COVERAGE_DIR']
    command_name "avalara_shard_#{suffix}"
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
require 'spree/testing_support/rspec_retry_config'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'progress'
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods

  # Same as core's spec_helper: Spree::Current must not leak between examples —
  # under SQLite, rolled-back transactions reuse row ids, so a stale cache entry
  # can collide with a later example's records.
  #
  # @default_store is one shared instance created outside the per-example
  # transaction: an update! inside an example rolls back in the database but
  # stays mutated in memory, and the next example's save re-persists the stale
  # preferences. Reload drops the leak.
  config.before do
    Spree::Current.reset
    @default_store.reload if defined?(@default_store) && @default_store&.persisted?
  end

  config.before(:suite) do
    Spree::Events.disable!
  end

  config.order = :random
  Kernel.srand config.seed
end
