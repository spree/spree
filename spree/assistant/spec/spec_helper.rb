# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

begin
  require File.expand_path('dummy/config/environment', __dir__)
rescue LoadError
  puts 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
end

require 'rspec/rails'

require 'spree/testing_support/factories'
require 'spree/testing_support/jobs'
require 'spree/testing_support/store'
require 'spree/api/testing_support/v3/base'
require 'spree/api/testing_support/agent_dispatch_headers'

require 'spree/assistant/testing_support/scripted_provider'

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'progress'
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods
  config.include Spree::Assistant::TestingSupport::ScriptedProvider

  config.before { reset_scripted_provider! }

  config.order = :random
  Kernel.srand config.seed
end
