require 'capybara-screenshot/rspec'

Capybara.configure do |config|
  config.save_path = ENV['CIRCLE_ARTIFACTS'] if ENV['CIRCLE_ARTIFACTS']
  config.server = :puma
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = ENV.fetch('CAPYBARA_MAX_WAIT_TIME', 45).to_i
  config.always_include_port = true
  config.match = :smart
  config.ignore_hidden_elements = true
end
Capybara.test_id = 'data-test-id'

if ENV['WEBDRIVER'] == 'accessible'
  require 'capybara/accessible'
  Capybara.javascript_driver = :accessible
end

Capybara.register_driver :selenium_chrome_headless do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new

  options.add_argument '--headless=new'
  options.add_argument '--disable-gpu'

  # Larger window size helps with dialog rendering in headless mode
  options.add_argument '--window-size=1920,1080'
  options.add_argument '--disable-search-engine-choice-screen'

  # Required for running in Docker containers (CircleCI)
  options.add_argument '--no-sandbox'
  options.add_argument '--disable-dev-shm-usage'

  # Disable timers being throttled in background pages/tabs. Useful for parallel test runs.
  options.add_argument '--disable-background-timer-throttling'

  # Normally, Chrome will treat a 'foreground' tab instead as backgrounded if the surrounding window is occluded (aka
  # visually covered) by another window. This flag disables that. Useful for parallel test runs.
  options.add_argument '--disable-backgrounding-occluded-windows'

  # This disables non-foreground tabs from getting a lower process priority. Useful for parallel test runs.
  options.add_argument '--disable-renderer-backgrounding'

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
