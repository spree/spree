if ENV['COVERAGE']
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Libraries', 'lib/spree'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/generators/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/backend" if ENV['COVERAGE_DIR']
  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

begin
  require File.expand_path('../dummy/config/environment', __FILE__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `BUNDLE_GEMFILE=../Gemfile bundle exec rake test_app`'
  exit
end

require 'rspec/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'capybara-select-2'
require 'database_cleaner'
require 'ffaker'

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/capybara_config'
require 'spree/testing_support/rspec_retry_config'
require 'spree/testing_support/image_helpers'
require 'spree/testing_support/flatpickr_capybara'

require 'spree/core/controller_helpers/strong_parameters'
require 'webdrivers'

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
  config.use_transactional_fixtures = false

  config.before :suite do
    Capybara.match = :smart
    DatabaseCleaner.clean_with :truncation
  end

  config.before do
    Rails.cache.clear
    WebMock.disable!
    DatabaseCleaner.strategy = if RSpec.current_example.metadata[:js]
                                 :truncation
                               else
                                 :transaction
                               end
    # TODO: Find out why open_transactions ever gets below 0
    # See issue #3428
    ApplicationRecord.connection.increment_open_transactions if ApplicationRecord.connection.open_transactions < 0

    DatabaseCleaner.start
    reset_spree_preferences
  end

  config.after(:each, type: :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end

  config.append_after do
    DatabaseCleaner.clean
  end

  config.include CapybaraSelect2
  config.include CapybaraSelect2::Helpers
  config.include FactoryBot::Syntax::Methods

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::Flash
  config.include Spree::TestingSupport::ImageHelpers
  config.include Spree::TestingSupport::FlatpickrCapybara

  config.include Spree::Core::ControllerHelpers::StrongParameters, type: :controller

  config.order = :random
  Kernel.srand config.seed

  config.filter_run_including focus: true unless ENV['CI']
  config.run_all_when_everything_filtered = true
end

module Spree
  module TestingSupport
    module Flash
      def assert_admin_flash_alert_success(message)
        message_content = convert_flash(message)

        within('#FlashAlertsContainer', visible: :all) do
          expect(page).to have_css('span[data-alert-type="success"]', text: message_content, visible: :all)
        end
      end

      def assert_admin_flash_alert_error(message)
        message_content = convert_flash(message)

        within('#FlashAlertsContainer', visible: :all) do
          expect(page).to have_css('span[data-alert-type="error"]', text: message_content, visible: :all)
        end
      end

      def assert_admin_flash_alert_notice(message)
        message_content = convert_flash(message)

        within('#FlashAlertsContainer', visible: :all) do
          expect(page).to have_css('span[data-alert-type="notice"]', text: message_content, visible: :all)
        end
      end
    end
  end
end
