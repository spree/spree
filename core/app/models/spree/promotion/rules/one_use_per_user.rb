module Spree
  class Promotion
    module Rules
      class OneUsePerUser < PromotionRule
        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          order.user.present? && !promotion.used_by?(order.user, [order])
        end
      end
    end
  end
end

