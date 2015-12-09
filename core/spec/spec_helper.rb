require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.infect(RSpec.configuration, Pathname.new(__dir__))

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

  config.around do |example|
    Timeout.timeout(40, &example)
  end
end
