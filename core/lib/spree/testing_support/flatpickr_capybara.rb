module Spree
  module TestingSupport
    module FlatpickrCapybara
      def fill_in_date_manually(label_text, with:)
        with_open_flatpickr(label_text) do |field|
          fill_in field[:id], with: with
        end
      end

      def fill_in_date_picker(label_text, with:)
        within_open_flatpickr(label_text) do
          within_flatpickr_months do
            fill_in_flatpickr_year(with.split('-')[0])

            select_flatpickr_month(with.split('-')[1])

            click_on_flatpickr_day(with.split('-')[2])
          end
        end
      end

      def fill_in_date_time_picker(label_text, with:)
        within_open_flatpickr(label_text) do
          within_flatpickr_months do
            fill_in_flatpickr_year(with.split('-')[0])

            select_flatpickr_month(with.split('-')[1])

            click_on_flatpickr_day(with.split('-')[2])
          end

          within_flatpickr_time do
            select_flatpickr_hour(with.split('-')[3])

            select_flatpickr_min(with.split('-')[4])
          end
        end
      end

      def fill_in_date_with_js(label_text, with:)
        date_field = find("input[id='#{label_text}']")
        script = "document.querySelector('#{date_field}').flatpickr().setDate('#{with}');"

        page.execute_script(script)
      end

      private

      def with_open_flatpickr(label_text)
        field_label = find_field(id: label_text, type: :hidden)

        date_field = field_label.sibling('.flatpickr-alt-input')
        date_field.click            # Open the widget

        sleep(0.25)                 # Pause to let JavaScript populate DOM

        yield(date_field)           # Complete required action

        date_field.send_keys :tab   # Close the date picker widget
      end

      def within_open_flatpickr(label_text, &block)
        with_open_flatpickr(label_text) do
          within find('.flatpickr-calendar.open', &block)
        end
      end

      def within_flatpickr_months(&block)
        within find('.flatpickr-months > .flatpickr-month > .flatpickr-current-month', &block)
      end

      def within_flatpickr_time(&block)
        within find('.flatpickr-time', &block)
      end

      def select_flatpickr_month(month)
        accurate_month = (month.to_i - 1)

        find("select.flatpickr-monthDropdown-months > option[value='#{accurate_month}']").select_option
      end

      def fill_in_flatpickr_year(year)
        find('input.cur-year').set(year)
      end

      def click_on_flatpickr_day(day)
        within_flatpickr_days do
          find('.flatpickr-day:not(.prevMonthDay):not(.nextMonthDay)', text: day, exact_text: true).click
        end
      end

      def within_flatpickr_days(&block)
        within find('.flatpickr-innerContainer > .flatpickr-rContainer > .flatpickr-days > .dayContainer', &block)
      end

      def select_flatpickr_hour(hour)
        find('input.flatpickr-hour').set(hour)
      end

      def select_flatpickr_min(min)
        find('input.flatpickr-minute').set(min)
      end
    end
  end
end
