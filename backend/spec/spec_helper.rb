require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.new(__dir__)
  .dummy_app
  .support

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/capybara_ext'

require 'paperclip/matchers'

require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist

# Set timeout to something high enough to allow CI to pass
Capybara.default_wait_time = 10

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  config.before :suite do
    Capybara.match = :prefer_exact
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do
    Rails.cache.clear
    WebMock.disable!
    if RSpec.current_example.metadata[:js]
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end

    DatabaseCleaner.start
    reset_spree_preferences
  end

  config.after(:each) do
    # Ensure js requests finish processing before advancing to the next test
    wait_for_ajax if RSpec.current_example.metadata[:js]

    DatabaseCleaner.clean
  end

  config.around do |example|
    Timeout.timeout(20, &example)
  end

  config.after(:each, :type => :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end

  config.include FactoryGirl::Syntax::Methods

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests
  config.include Spree::TestingSupport::Flash

  config.include Paperclip::Shoulda::Matchers

  config.extend WithModel
end
