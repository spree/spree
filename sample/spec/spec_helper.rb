require File.expand_path('../../shared/spec_helper.rb', __dir__)

SpecHelper.new(__dir__).dummy_app

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.include FactoryGirl::Syntax::Methods
end
