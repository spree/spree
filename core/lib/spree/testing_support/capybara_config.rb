require 'capybara-screenshot/rspec'

Capybara.save_path = ENV['CIRCLE_ARTIFACTS'] if ENV['CIRCLE_ARTIFACTS']

if ENV['WEBDRIVER'] == 'accessible'
  require 'capybara/accessible'
  Capybara.javascript_driver = :accessible
else
  Capybara.register_driver :chrome do |app|
    Selenium::WebDriver.logger.level = :error

    Capybara::Selenium::Driver.new app,
      browser: :chrome,
      options: Selenium::WebDriver::Chrome::Options.new(
        args: %w[no-sandbox disable-dev-shm-usage disable-popup-blocking headless disable-gpu window-size=1920,1080 --enable-features=NetworkService,NetworkServiceInProcess --disable-features=VizDisplayCompositor],
        log_level: :error
      )
  end
  Capybara.javascript_driver = :chrome

  Capybara::Screenshot.register_driver(:chrome) do |driver, path|
    driver.browser.save_screenshot(path)
  end
end
Capybara.default_max_wait_time = 45
Capybara.server = :webrick
