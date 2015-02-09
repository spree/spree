module Spree
  class Promotion
    module Rules
      class OneUsePerUser < PromotionRule
        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          if order.user.present? && promotion.used_by?(order.user, [order])
            add_eligibility_error(:limit_once_per_user)
          else
            add_eligibility_error(:no_user_specified)
          end

          eligibility_errors.empty?
        end
      end
    end
  end
end

