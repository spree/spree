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
end

RSpec.configure do |c|
  c.include CapybaraExt
end
