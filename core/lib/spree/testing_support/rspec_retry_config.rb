require 'rspec/retry'

RSpec.configure do |config|
  config.verbose_retry = true
  config.display_try_failure_messages = true

  config.around :each, type: :feature do |ex|
    ex.run_with_retry retry: ENV.fetch('RSPEC_RETRY_RETRY_COUNT', 3).to_i
  end
end
