module Spree
  class Promotion
    module Rules
      class FirstOrder < PromotionRule
        def eligible?(order, options = {})
          user = order.try(:user) || options[:user]
          if user
            return orders_by_email(user.email) == 0
          elsif order.email
            return orders_by_email(order.email) == 0
          end

          return false
        end

        def orders_by_email(email)
          Spree::Order.where(:email => email).count
        end
      end
    end
  end
end
