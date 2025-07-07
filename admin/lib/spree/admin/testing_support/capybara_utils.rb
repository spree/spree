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
      end
    end
  end
end
