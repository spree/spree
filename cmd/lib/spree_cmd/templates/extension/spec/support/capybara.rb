require 'capybara/rspec'
require 'capybara-screenshot'
require 'capybara-screenshot/rspec'
require 'capybara/rails'

RSpec.configure do
  Capybara.register_driver :chrome do |app|
    Selenium::WebDriver.logger.level = :error

    Capybara::Selenium::Driver.new app,
      browser: :chrome,
      options: Selenium::WebDriver::Chrome::Options.new(
        args: %w[headless disable-gpu window-size=1920,1080 --enable-features=NetworkService,NetworkServiceInProcess --disable-features=VizDisplayCompositor],
        log_level: :error
      )
  end
  Capybara.javascript_driver = :chrome

  Capybara::Screenshot.register_driver(:chrome) do |driver, path|
    driver.browser.save_screenshot(path)
  end

end
