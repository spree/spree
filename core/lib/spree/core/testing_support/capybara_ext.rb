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

  def select2_search(within, value)
    # Forced narcolepsy, thanks to JavaScript
    sleep(0.25)
    page.execute_script "$('#{within} .select2-choice').mousedown();"
    page.execute_script "$('#{within} .select2-choices').mousedown();"
    sleep(0.25)
    page.execute_script "$('input.select2-input').val('#{value}').trigger('keyup-change');"

    wait_until do
      page.find(".select2-highlighted", :visible => true)
    end

    page.execute_script "$('.select2-highlighted').mouseup();"
  end


  def select2(value, options)
    # find label and its for attribute
    label = first(:xpath, "//label[text()='#{options[:from]}']")
    id = label ? label['for'] : options[:from]

    # generate select2 id
    select2_id = "#s2id_#{id}"

    # find select2 element and click it
    find("#{select2_id}").find('a').click

    # search results and click
    res = find("ul.select2-results")
    res.find(:xpath, %Q{//div[@class="select2-result-label" and text()="#{value}"]}).click()
  end

end

RSpec.configure do |c|
  c.include CapybaraExt
end
