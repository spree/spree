module Spree
  class Promotion::Rules::FirstOrder < PromotionRule
    def eligible?(order, options = {})
      order.user && order.user.orders.complete.count == 0
    end
  end
end
