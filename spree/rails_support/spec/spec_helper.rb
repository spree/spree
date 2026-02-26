if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.root(ENV.fetch('GITHUB_WORKSPACE', File.expand_path('../../..', __dir__)))
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  SimpleCov.start 'rails' do
    add_group 'Finders', 'app/finders'
    add_group 'Presenters', 'app/presenters'
    add_group 'Sorters', 'app/sorters'
    add_group 'Libraries', 'lib/spree'

    add_filter '/app/assets/'
    add_filter '/app/views/'
    add_filter '/bin/'
    add_filter '/config/'
    add_filter '/db/'
    add_filter '/lib/generators/'
    add_filter '/lib/spree/testing_support/'
    add_filter '/lib/tasks/'
    add_filter '/script/'
    add_filter '/spec/'

    if ENV['COVERAGE_DIR']
      shard = ENV.fetch('CI_SHARD', '1')
      coverage_dir "#{ENV['COVERAGE_DIR']}/rails_support_#{shard}"
    end
    command_name "rails_support_shard_#{ENV.fetch('CI_SHARD', '1')}"
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

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/testing_support/preferences'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/kernel'
require 'spree/testing_support/rspec_retry_config'

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
  end

  config.include FactoryBot::Syntax::Methods
  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::Kernel

  config.order = :random
  Kernel.srand config.seed
end
