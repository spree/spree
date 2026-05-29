module Spree
  module PriceRules
    class CustomerGroupRule < Spree::PriceRule
      # Stored as raw IDs. Accepts prefixed IDs (`cg_…`) from API
      # callers and decodes them on write so eligibility checks compare
      # against raw `customer_group_id` rows directly. Scope confines
      # the existence check to the price-list's store.
      preference :customer_group_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::CustomerGroup,
                   scope: ->(rule) { rule.store.customer_groups }
                 )

      def customer_groups
        return [] if preferred_customer_group_ids.blank?

        Spree::CustomerGroup.where(id: preferred_customer_group_ids)
      end

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
