module Spree
  class Promotion
    module Rules
      class CustomerGroup < PromotionRule
        preference :customer_group_ids, :array, default: []

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          return false unless order.user_id.present?
          return false if preferred_customer_group_ids.empty?

          user_customer_group_ids = Spree::CustomerGroupUser.where(user_id: order.user_id).pluck(:customer_group_id).map(&:to_s)

          (preferred_customer_group_ids.map(&:to_s) & user_customer_group_ids).any?
        end
      end
    end
  end
end
