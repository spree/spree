module Spree
  class Promotion
    module Rules
      class OneUsePerUser < Spree::PromotionRule
        def eligible?(order, _options = {})
          if order.customer.present?
            if promotion.used_by?(order.customer, [order])
              eligibility_errors.add(:base, eligibility_error_message(:limit_once_per_user))
            end
          else
            eligibility_errors.add(:base, eligibility_error_message(:no_user_specified))
          end

          eligibility_errors.empty?
        end
      end
    end
  end
end
