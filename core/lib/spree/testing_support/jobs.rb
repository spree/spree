RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.before(:each, :job) do
    ActiveJob::Base.queue_adapter = :test
  end

  config.after(:each, :job) do
    ActiveJob::Base.queue_adapter = :inline
  end
end
