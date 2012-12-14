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

    select2_id = "#s2id_#{id}"
    find(select2_id).find(".select2-choices").click
    page.execute_script "$('#{select2_id} input.select2-input').val('#{value}').trigger('keyup-change');"
    select_select2_result(value)
  end

  def select2(value, options)
    id = find_label_by_text(options[:from])

    # generate select2 id
    select2_id = "#s2id_#{id}"

    # find select2 element and click it
    find("#{select2_id}").find('a').click
    select_select2_result(value)
  end

  def select_select2_result(value)
    find(:xpath, %Q{//div[@class="select2-result-label" and text()="#{value}"]}).click
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
    first(:xpath, "//label[text()='#{text}']")
  end

end

RSpec.configure do |c|
  c.include CapybaraExt
end
