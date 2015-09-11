require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.new(__dir__)

RSpec.configure do |config|
  config.color = true
  config.mock_with :rspec

  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.use_transactional_fixtures = false
end
