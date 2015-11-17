require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.new(__dir__)
  .dummy_app
  .support

if ENV.key?('CHECK_TRANSLATIONS')
  require 'spree/testing_support/i18n'
end

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/caching'

require 'paperclip/matchers'

require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  config.fixture_path = File.join(File.expand_path(File.dirname(__FILE__)), "fixtures")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # Ensure DB is clean, so that transaction isolated specs see
  # prisitine state.
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  config.before(:each) do
    if RSpec.current_example.metadata[:js]
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
    reset_spree_preferences
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.after(:each, :type => :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      #binding.pry
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
end
