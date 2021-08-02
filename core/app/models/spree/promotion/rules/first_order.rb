module Spree
  class Promotion
    module Rules
      class FirstOrder < PromotionRule
        attr_reader :user, :email, :store

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          @user = order.try(:user) || options[:user]
          @email = order.email
          @store = order.store

          if user || email
            if !completed_orders.blank? && completed_orders.first != order
              eligibility_errors.add(:base, eligibility_error_message(:not_first_order))
            end
          else
            eligibility_errors.add(:base, eligibility_error_message(:no_user_or_email_specified))
          end

          eligibility_errors.empty?
        end

        private

        def completed_orders
          user ? user.orders.for_store(store).complete : orders_by_email
        end

        def orders_by_email
          store.orders.where(email: email).complete
        end
      end
    end
  end
end
