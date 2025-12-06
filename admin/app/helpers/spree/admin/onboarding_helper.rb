module Spree
  module Admin
    module OnboardingHelper
      def onboarding_check_circle(condition, pending: false)
        if pending
          return icon('exclamation-circle', height: height,
                                            class: 'rounded-full inline-flex items-center bg-warning text-primary p-1').html_safe
        end

        if condition == true
          icon('check', class: 'rounded-full inline-flex items-center bg-green-200 text-green-600 border-green-200 p-1')
        else
          icon('check', class: 'rounded-full inline-flex items-center border-dashed text-gray-300 p-1')
        end.html_safe
      end
    end
  end
end
