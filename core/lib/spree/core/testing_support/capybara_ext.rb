module CapybaraExt
  def page!
    save_and_open_page
  end

  def click_icon(type)
    find(".icon-#{type}").click
  end

  def eventually_fill_in(field, options={})
    Capybara.wait_until do
      find_field field
    end
    fill_in field, options
  end

  def within_row(num, &block)
    within("table.index tbody tr:nth-child(#{num})", &block)
  end

  def column_text(num)
    find("td:nth-child(#{num})").text
  end

  def set_select2_field(field, value)
    page.execute_script %Q{$('#{field}').select2('val', '#{value}')}
  end

  def select2_search(value, options)
    id = find_label_by_text(options[:from])
    options[:from] = "#s2id_#{id}"
    targetted_select2_search(value, options)
  end

  def targetted_select2_search(value, options)
    scope = find(options[:from])
    begin
      find(".select2-choices").click
    rescue Capybara::ElementNotFound
      find(".select2-choice").click
    end

    page.execute_script "$('#{options[:from]} input.select2-input').val('#{value}').trigger('keyup-change');"
    select_select2_result(value)
  end

  def select2(value, options)
    id = find_label_by_text(options[:from])

    # generate select2 id
    options[:from] = "#s2id_#{id}"
    targetted_select2(value, options)
  end

  def targetted_select2(value, options)
    # find select2 element and click it
    find(options[:from]).find('a').click
    select_select2_result(value)
  end

  def select_select2_result(value)
    begin
      find(:xpath, %Q{//div[@class="select2-result-label" and text()[contains(.,"#{value}")]]}).click
    rescue Capybara::ElementNotFound
      results = all(:xpath, %Q{//div[@class="select2-result-label"]})
      if results.count == 1
        results.first.click
      else
        raise "Couldn't disambiguate select2 result."
      end
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

    if label.nil?
      raise "Could not find label by text #{text}"
    end

    label ? label['for'] : text
  end

  def find_label(text)
    first(:xpath, "//label[text()[contains(.,'#{text}')]]")
  end

end

RSpec.configure do |c|
  c.include CapybaraExt
end
