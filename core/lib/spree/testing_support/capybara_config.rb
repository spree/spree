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

if ENV['WEBDRIVER'] == 'accessible'
  require 'capybara/accessible'
  Capybara.javascript_driver = :accessible
end

Capybara.register_driver :selenium_chrome_headless do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument '--headless'
  options.add_argument '--disable-gpu'
  options.add_argument '--window-size=1400,900'
  options.add_argument '--disable-search-engine-choice-screen'

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
