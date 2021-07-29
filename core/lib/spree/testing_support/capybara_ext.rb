module CapybaraExt
  # https://bugs.chromium.org/p/chromedriver/issues/detail?id=1771
  def delayed_fill_in(selector, text)
    field = find_field(selector)
    text.to_s.split('').each do |char|
      sleep 0.05
      field.send_keys(char)
    end
  end

  def page!
    save_and_open_page
  end

  def click_icon(type)
    first(".icon-#{type}").click
  end

  def within_row(num, &block)
    if RSpec.current_example.metadata[:js]
      within("table.table tbody tr:nth-child(#{num})", match: :first, &block)
    else
      within(all('table.table tbody tr')[num - 1], &block)
    end
  end

  def column_text(num)
    if RSpec.current_example.metadata[:js]
      find("td:nth-child(#{num})").text
    else
      all('td')[num - 1].text
    end
  end

  def wait_for_ajax
    max_time = Capybara::Helpers.monotonic_time + Capybara.default_max_wait_time
    while Capybara::Helpers.monotonic_time < max_time
      finished = finished_all_ajax_requests?
      if finished
        break
      else
        sleep 0.1
      end
    end
    raise 'wait_for_ajax timeout' unless finished
  end

  def finished_all_ajax_requests?
    page.evaluate_script(<<~JSX
      ((typeof window.jQuery === 'undefined') || (typeof window.jQuery.active === 'undefined') || (window.jQuery.active === 0))
      && ((typeof window.injectedJQueryFromNode === 'undefined') || (typeof window.injectedJQueryFromNode.active === 'undefined') || (window.injectedJQueryFromNode.active === 0))
      && ((typeof window.httpClients === 'undefined') || (window.httpClients.every(function (client) { return (client.activeRequestCount === 0); })))
    JSX
                        )
  end

  def wait_for_condition(delay = Capybara.default_max_wait_time)
    counter = 0
    delay_threshold = delay * 10
    until yield
      counter += 1
      sleep(0.1)
      raise "Could not achieve condition within #{delay} seconds." if counter >= delay_threshold
    end
  end

  def disable_html5_validation
    page.execute_script('for(var f=document.forms,i=f.length;i--;)f[i].setAttribute("novalidate",i)')
  end
end

def wait_for(options = {}, &block)
  default_options = { error: nil, seconds: 5 }.merge(options)

  Selenium::WebDriver::Wait.new(timeout: default_options[:seconds]).until(&block)
rescue Selenium::WebDriver::Error::TimeOutError
  default_options[:error].nil? ? false : raise(default_options[:error])
end

Capybara.configure do |config|
  config.match = :smart
  config.ignore_hidden_elements = true
end

RSpec::Matchers.define :have_meta do |name, expected|
  match do |_actual|
    has_css?("meta[name='#{name}'][content='#{expected}']", visible: false)
  end

  failure_message do |actual|
    actual = first("meta[name='#{name}']")
    if actual
      "expected that meta #{name} would have content='#{expected}' but was '#{actual[:content]}'"
    else
      "expected that meta #{name} would exist with content='#{expected}'"
    end
  end
end

RSpec.configure do |c|
  c.include CapybaraExt
end
