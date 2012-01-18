module Spree
  class Promotion::Rules::FirstOrder < PromotionRule
    def eligible?(order, options = {})
      !!(options[:user] && options[:user].orders.complete.count == 0)
    end
  end
end
