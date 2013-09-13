module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          return order.try(:user).try(:anonymous?) == false
        end

      end
    end
  end
end
