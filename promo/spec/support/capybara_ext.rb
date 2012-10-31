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

  def eventually_fill_in(field, options={})
    Capybara.wait_until do
      find_field field
    end
    fill_in field, options
  end
end

RSpec.configure do |c|
  c.include CapybaraExt
end
