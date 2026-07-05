module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule
        # Wire-format shorthand is `customer_logged_in` (the model is still
        # `UserLoggedIn` pre-6.0 rename, see docs/plans/6.0-platform-auth.md).
        def self.api_type
          'customer_logged_in'
        end

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          unless order.user.present?
            eligibility_errors.add(:base, eligibility_error_message(:no_user_specified))
          end
          eligibility_errors.empty?
        end
      end
    end
  end
end
