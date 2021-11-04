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

RSpec.configure do |config|
  config.before(:each, js: true) do
    Capybara.page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
