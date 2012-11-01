module CapybaraExt
  def page!
    save_and_open_page
  end

  # A hack so that we can test select2 things within our integration tests
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
