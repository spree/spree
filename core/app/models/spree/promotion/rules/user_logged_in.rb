module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule
        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          add_eligibility_error(:no_user_specified) unless order.user.present?
          eligibility_errors.empty?
        end
      end
    end
  end
end
