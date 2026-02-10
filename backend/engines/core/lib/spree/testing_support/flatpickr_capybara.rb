module Spree
  module TestingSupport
    module FlatpickrCapybara
      def fill_in_date_manually(label_text, options = {})
        with_open_flatpickr(label_text) do |field|
          fill_in field[:id], with: string_date(options)
        end
      end

      def fill_in_date_picker(label_text, options = {})
        if options[:hour].blank? && options[:minute].blank?
          flatpickr_date_only(label_text, options)
        else
          flatpickr_date_time(label_text, options)
        end
      end

      def fill_in_date_with_js(label_text, options = {})
        date_field = find("input[id='#{label_text}']")
        script = "document.querySelector('#{date_field}').flatpickr().setDate('#{string_date(options)}');"

        page.execute_script(script)
      end

      private

      def flatpickr_date_only(label_text, options = {})
        within_open_flatpickr(label_text) do
          within_flatpickr_months do
            fill_in_flatpickr_year(options[:year].to_i)
            sleep(0.25) # Pause to let JavaScript adjust the month selector in the flatpickr cal in relation to any related FROM...TO cal.

            select_flatpickr_month(options[:month].to_i)
            sleep(0.25) # Pause to let JavaScript adjust the day selection area in the flatpickr cal in relation to any related FROM...TO cal.

            click_on_flatpickr_day(options[:day].to_i)
          end
        end
      end

      def flatpickr_date_time(label_text, options = {})
        within_open_flatpickr(label_text) do
          within_flatpickr_months do
            fill_in_flatpickr_year(options[:year].to_i)
            sleep(0.25) # Pause to let JavaScript adjust the month selector in the flatpickr cal in relation to any related FROM...TO cal.

            select_flatpickr_month(options[:month].to_i)
            sleep(0.25) # Pause to let JavaScript adjust the day selection area in the flatpickr cal in relation to any related FROM...TO cal.

            click_on_flatpickr_day(options[:day].to_i)
          end

          within_flatpickr_time do
            select_flatpickr_hour(options[:hour].to_i)
            select_flatpickr_min(options[:minute].to_i)
          end
        end
      end

      def with_open_flatpickr(label_text)
        field_label = find_field(id: label_text, type: :hidden)

        date_field = field_label.sibling('.flatpickr-alt-input')
        date_field.click # Open the flatpickr cal.
        sleep(0.25) # Pause to let JavaScript populate DOM with an open flatpickr cal.

        yield(date_field) # Complete required action within the open flatpickr cal.

        date_field.send_keys :tab # Close the date flatpickr cal.
        sleep(0.25) # Pause to let JavaScript adjust any DOM values in relation to any related FROM...TO cal.
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

      def string_date(options)
        if options[:hour].present? && options[:minute].present?
          "#{options[:year]}-#{options[:month]}-#{options[:day]}-#{options[:hour]}-#{options[:minute]}"
        else
          "#{options[:year]}-#{options[:month]}-#{options[:day]}"
        end
      end
    end
  end
end
