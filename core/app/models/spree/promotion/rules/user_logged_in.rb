module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule
        def eligible?(order, options = {})
          return order.user.present?
        end
      end
    end
  end
end
