module Spree
  class Promotion
    module Rules
      class FirstOrder < PromotionRule
        def eligible?(order, options = {})
          user = order.try(:user) || options[:user]
          !!(user && user.orders.complete.count == 0)
        end
      end
    end
  end
end
