module CapybaraExt
  def page!
    save_and_open_page
  end

  def click_icon(type)
    find(".icon-#{type}").click
  end

  def within_row(num, &block)
    within("table.index tbody tr:nth-child(#{num})", &block)
  end

  def column_text(num)
    find("td:nth-child(#{num})").text
  end

  def select2(within, value)
    script = %Q{
      $('#{within} .select2-search-field input').val('#{value}')
      $('#{within} .select2-search-field input').keydown();
    }
    page.execute_script(script)

    # Wait for list to populate...
    wait_until do
      page.find(".select2-highlighted").visible?
    end
    page.execute_script("$('.select2-highlighted').mouseup();")
  end
end

RSpec.configure do |c|
  c.include CapybaraExt
end
