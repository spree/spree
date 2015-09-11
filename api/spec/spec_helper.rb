require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.new(__dir__)
  .dummy_app
  .support

require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'

require 'spree/api/testing_support/caching'
require 'spree/api/testing_support/helpers'
require 'spree/api/testing_support/setup'

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [/gems\/activesupport/, /gems\/actionpack/, /gems\/rspec/]
  config.color = true
  config.infer_spec_type_from_file_location!

  config.include FactoryGirl::Syntax::Methods
  config.include Spree::Api::TestingSupport::Helpers, :type => :controller
  config.extend Spree::Api::TestingSupport::Setup, :type => :controller
  config.include Spree::TestingSupport::Preferences, :type => :controller

  config.before do
    Spree::Api::Config[:requires_authentication] = true
  end

  config.use_transactional_fixtures = true
end
