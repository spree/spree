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
    find(".icon-#{type}").click
  end

  def within_row(num, &block)
    if RSpec.current_example.metadata[:js]
      within("table.table tbody tr:nth-child(#{num})", &block)
    else
      within(:xpath, all('table.table tbody tr')[num - 1].path, &block)
    end
  end

  def column_text(num)
    if RSpec.current_example.metadata[:js]
      find("td:nth-child(#{num})").text
    else
      all('td')[num - 1].text
    end
  end

  def set_select2_field(field, value)
    page.execute_script %Q{$('#{field}').select2('val', '#{value}')}
  end

  def select2_search(value, options)
    label = find_label_by_text(options[:from])
    within label.first(:xpath, './/..') do
      options[:from] = "##{find('.select2-container')['id']}"
    end
    targetted_select2_search(value, options)
  end

  def targetted_select2_search(value, options)
    select2_el = find(:css, options[:from])
    page.execute_script "$(arguments[0]).select2('open')", select2_el
    page.execute_script "$('#{options[:dropdown_css]} input.select2-input').val('#{value}').trigger('keyup-change');"
    select_select2_result(value)
  end

  def select2(value, options)
    label = find_label_by_text(options[:from])

    within label.first(:xpath, './/..') do
      options[:from] = "##{find('.select2-container')['id']}"
    end
    targetted_select2(value, options)
  end

  def select2_no_label(value, options = {})
    raise "Must pass a hash containing 'from'" if !options.is_a?(Hash) || !options.key?(:from)

    placeholder = options[:from]
    click_link placeholder

    select_select2_result(value)
  end

  def targetted_select2(value, options)
    # find select2 element and click it
    find(options[:from]).find('a').click
    select_select2_result(value)
  end

  def select_select2_result(value)
    # results are in a div appended to the end of the document
    within(:xpath, '//body') do
      page.find('div.select2-result-label', text: %r{#{Regexp.escape(value)}}i).click
    end
  end

  def find_label_by_text(text)
    label = find_label(text)
    counter = 0

    # Because JavaScript testing is prone to errors...
    while label.nil? && counter < 10
      sleep(1)
      counter += 1
      label = find_label(text)
    end

    raise "Could not find label by text #{text}" if label.nil?

    label
  end

  def find_label(text)
    first(:xpath, "//label[text()[contains(.,'#{text}')]]")
  end

  # arg delay in seconds
  def wait_for_ajax(delay = Capybara.default_max_wait_time)
    Timeout.timeout(delay) do
      active = page.evaluate_script('typeof jQuery !== "undefined" && jQuery.active')
      active = page.evaluate_script('typeof jQuery !== "undefined" && jQuery.active') until active.nil? || active.zero?
    end
  end

  def disable_html5_validation
    page.execute_script('for(var f=document.forms,i=f.length;i--;)f[i].setAttribute("novalidate",i)')
  end
end

def wait_for(options = {})
  default_options = { error: nil, seconds: 5 }.merge(options)

  Selenium::WebDriver::Wait.new(timeout: default_options[:seconds]).until { yield }
rescue Selenium::WebDriver::Error::TimeOutError
  default_options[:error].nil? ? false : raise(default_options[:error])
end

Capybara.configure do |config|
  config.match = :prefer_exact
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
