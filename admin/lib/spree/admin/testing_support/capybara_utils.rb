module Spree
  module Admin
    module TestingSupport
      module CapybaraUtils
        def click_icon(type)
          first(".ti-#{type}").click
        end

        def within_row(num, &block)
          if RSpec.current_example.metadata[:js]
            within("table.table tbody tr:nth-child(#{num})", match: :first, &block)
          else
            within(all('table.table tbody tr')[num - 1], &block)
          end
        end

        # delay in seconds
        def wait_for_ajax(delay = Capybara.default_max_wait_time)
          Timeout.timeout(delay) do
            active = page.evaluate_script('typeof jQuery !== "undefined" && jQuery.active')
            active = page.evaluate_script('typeof jQuery !== "undefined" && jQuery.active') until active.nil? || active.zero?
          end
        end

        def wait_for_turbo(timeout = nil)
          if has_css?('.turbo-progress-bar', visible: true, wait: 1.seconds)
            has_no_css?('.turbo-progress-bar', wait: timeout.presence || 5.seconds)
          end
        end

        def wait_for(options = {}, &block)
          default_options = { error: nil, seconds: 5 }.merge(options)

          Selenium::WebDriver::Wait.new(timeout: default_options[:seconds]).until(&block)
        rescue Selenium::WebDriver::Error::TimeoutError
          default_options[:error].nil? ? false : raise(default_options[:error])
        end

        def wait_for_dialog(selector = '#main-dialog', timeout: 5)
          # Wait for turbo to finish loading the dialog content
          wait_for_turbo(timeout)

          # Wait for the dialog element to be present and open
          # Note: Using visible: :all because headless Chrome may not consider dialogs "visible"
          # even when properly opened via showModal()
          has_css?("#{selector}[open]", visible: :all, wait: timeout)

          # Verify the dialog is actually open and rendered
          unless page.evaluate_script("document.querySelector('#{selector}')?.open")
            raise "Dialog #{selector} is not open"
          end

          # Give Chrome time to fully render the dialog and make elements interactable
          # The old headless mode is better but still needs a brief render pause
          sleep 0.3
        end
      end
    end
  end
end
