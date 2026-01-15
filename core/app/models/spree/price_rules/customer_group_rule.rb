module Spree
  module PriceRules
    class CustomerGroupRule < Spree::PriceRule
      preference :customer_group_ids, :array, default: []

      def applicable?(context)
        return false unless context.user
        return true if preferred_customer_group_ids.empty?

        user_customer_group_ids = Spree::CustomerGroupUser.where(user_id: context.user.id).pluck(:customer_group_id).map(&:to_s)

        # Compare as strings to support both integer and UUID primary keys
        (preferred_customer_group_ids.map(&:to_s) & user_customer_group_ids).any?
      end

      def self.description
        Spree.t('price_rules.customer_group_rule.description')
      end
    end
  end
end
