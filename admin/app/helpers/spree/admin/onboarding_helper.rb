module Spree
  module Admin
    module OnboardingHelper
      def onboarding_check_circle(condition, pending: false)
        if pending
          return icon('exclamation-circle', height: height,
                                            class: 'rounded-full inline-flex items-center bg-warning text-primary p-1').html_safe
        end

        if condition == true
          icon('check', class: 'rounded-full inline-flex items-center bg-success text-success p-1', style: 'border: 3px solid #C6F6D5')
        else
          icon('check', class: 'rounded-full inline-flex items-center border-dashed text-gray-300 p-1')
        end.html_safe
      end
    end
  end
end
