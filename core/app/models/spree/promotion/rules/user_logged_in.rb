module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule

        def eligible?(order, options = {})
          return order.try(:user).try(:anonymous?) == false
        end

      end
    end
  end
end
