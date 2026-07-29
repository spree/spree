module Spree
  module PromotionRules
    class OneUsePerUser < Spree::PromotionRule
      def applicable?(promotable)
        promotable.is_a?(Spree::Order) || promotable.is_a?(Spree::Cart)
      end

      def eligible?(order, _options = {})
        if order.user.present?
          if promotion.used_by?(order.user, [order])
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
