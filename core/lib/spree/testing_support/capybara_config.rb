require 'capybara-screenshot/rspec'

Capybara.register_driver :selenium_chrome_headless_ci do |app|
  version = Capybara::Selenium::Driver.load_selenium
  options_key = Capybara::Selenium::Driver::CAPS_VERSION.satisfied_by?(version) ? :capabilities : :options
  browser_options = ::Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.add_argument('--headless')
    opts.add_argument('--disable-gpu') if Gem.win_platform?
    # Workaround https://bugs.chromium.org/p/chromedriver/issues/detail?id=2650&q=load&sort=-id&colspec=ID%20Status%20Pri%20Owner%20Summary
    opts.add_argument('--disable-site-isolation-trials')
    opts.add_argument('--whitelisted-ips=')
  end

  Capybara::Selenium::Driver.new(app, **{ :browser => :chrome, options_key => browser_options })
end

Capybara.configure do |config|
  config.save_path = ENV['CIRCLE_ARTIFACTS'] if ENV['CIRCLE_ARTIFACTS']
  config.server = :puma
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_chrome_headless_ci
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
