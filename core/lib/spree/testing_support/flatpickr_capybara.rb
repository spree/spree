def fill_in_date_manually(label_text, with:)
  with_open_flatpickr(label_text) do |field|
    fill_in field[:id], with: with
  end
end

def fill_in_date_picker(label_text, with:)
  within_open_flatpickr(label_text) do
    within_flatpickr_months do
      select_flatpickr_month(with.split('-')[1])

      fill_in_flatpickr_year(with.split('-')[0])

      click_on_flatpickr_day(with.split('-')[2])
    end
  end
end

def with_open_flatpickr(label_text)
  field_label = find_field(id: label_text, type: :hidden)

  date_field = field_label.sibling('.input')
  date_field.click # Open the widget

  yield(date_field)

  date_field.send_keys :tab # Close the date picker widget
end

def within_open_flatpickr(label_text)
  with_open_flatpickr(label_text) do
    within find(:xpath, "/html/body/div[contains(@class, 'flatpickr-calendar')]") { yield }
  end
end

def within_flatpickr_months
  within find('.flatpickr-months .flatpickr-month .flatpickr-current-month') { yield }
end

def select_flatpickr_month(month)
  find("select.flatpickr-monthDropdown-months > option:nth-child(#{month.to_i})").select_option
end

def fill_in_flatpickr_year(year)
  find('input.cur-year').set(year)
end

def click_on_flatpickr_day(day)
  within_flatpickr_days do
    find('span', text: day).click
  end
end

def within_flatpickr_days
  within find('.flatpickr-innerContainer > .flatpickr-rContainer > .flatpickr-days') { yield }
end

def fill_in_date_with_js(label_text, with:)
  date_field = find("input[id='#{label_text}']")
  script = "document.querySelector('#{date_field}').flatpickr().setDate('#{with}');"

  page.execute_script(script)
end
