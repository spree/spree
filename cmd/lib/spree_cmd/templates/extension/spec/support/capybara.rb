require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'capybara/rails'
require 'webdrivers/chromedriver'
require 'selenium/webdriver'

if ENV['CIRCLE_NODE_INDEX'].present?
  Webdrivers.install_dir = File.expand_path('~/.webdrivers/' + ENV['CIRCLE_NODE_INDEX'].to_s)
end

# capybara-screenshot
Capybara.save_path = ENV.fetch('CIRCLE_ARTIFACTS', Rails.root.join('tmp', 'capybara')).to_s
Capybara::Screenshot.prune_strategy = { keep: 20 }
Capybara::Screenshot.register_driver(:chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    options: Selenium::WebDriver::Chrome::Options.new(
      args: %w[no-sandbox disable-dev-shm-usage disable-popup-blocking headless disable-gpu window-size=1920,1080 --enable-features=NetworkService,NetworkServiceInProcess --disable-features=VizDisplayCompositor],
      log_level: :error
    )
end

Capybara.javascript_driver = :chrome
