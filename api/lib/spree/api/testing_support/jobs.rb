RSpec.configure do |config|
  # Force jobs to be executed in a synchronous way (see http://archive.today/xcb1E)
  config.around do |example|
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    ActiveJob::Base.queue_adapter = :inline
    example.run
    (ActiveJob::Base.descendants << ActiveJob::Base).each { |a| a.enable_test_adapter(ActiveJob::QueueAdapters::TestAdapter.new) }
    ActiveJob::Base.queue_adapter = :test
  end

  config.before(:each, :job) do
    ActiveJob::Base.queue_adapter = :test
  end

  config.after(:each, :job) do
    ActiveJob::Base.queue_adapter = :inline
  end
end
