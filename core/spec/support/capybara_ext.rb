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

    # In separate executions as it needs that break between
    # Otherwise spec/requests/admin/products/edit/variants_spec breaks
    page.execute_script("$('.select2-highlighted').mouseup();")
  end
end

RSpec.configure do |c|
  c.include CapybaraExt
end
