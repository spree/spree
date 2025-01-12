module Spree
  module Storefront
    module TestingSupport
      module CapybaraUtils
        def wait_for_turbo(timeout = nil)
          if has_css?('.turbo-progress-bar', visible: true, wait: 1.seconds)
            has_no_css?('.turbo-progress-bar', wait: timeout.presence || 5.seconds)
          end
        end
      end
    end
  end
end
