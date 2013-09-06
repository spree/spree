module Spree
  class Promotion
    module Rules
      class CouponCode < PromotionRule
        validates :code, presence: true

        def eligible?(order)
          order.coupon_code.upcase == code.upcase
        end
      end
    end
  end
end
