module Spree
  class Promotion::Rules::FirstOrder < PromotionRule
    def eligible?(order, options = {})
      user = order.try(:user) || options[:user]
      !!(user && user.orders.complete.count == 0)
    end
  end
end
