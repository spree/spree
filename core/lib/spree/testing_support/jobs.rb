RSpec.configure do |config|
  config.before(:each, :job) do
    ActiveJob::Base.queue_adapter = :test
  end

  config.after(:each, :job) do
    ActiveJob::Base.queue_adapter = :inline
  end
end
