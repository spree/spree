module Spree
  module PriceRules
    # Superseded by catalog assignment, and grandfathered: existing rules
    # keep matching indefinitely, but new setups target a buyer by assigning
    # them a catalog that owns the price list
    # (docs/plans/6.0-catalog-agreement-rework.md). Hidden from the rule
    # picker; nothing new builds on it.
    class UserRule < Spree::PriceRule
      # Stored as raw IDs. Accepts prefixed IDs (the user class's prefix,
      # e.g. `usr_…`) from API callers and decodes them on write. Resolves
      # `Spree.customer_class` lazily — the user class is configured at boot,
      # and class-body evaluation runs before that on cold loads.
      preference :user_ids, :array, default: [], parse_on_set: ->(values) {
        normalize_id_preference(klass: Spree.customer_class).call(values)
      }

      def users
        return [] if preferred_user_ids.blank?

        Spree.customer_class.where(id: preferred_user_ids)
      end

      def applicable?(context)
        return false unless context.user
        return true if preferred_user_ids.empty?

        # Compare as strings to support both integer and UUID primary keys
        preferred_user_ids.map(&:to_s).include?(context.user.id.to_s)
      end

      def self.description
        'Apply pricing to specific customers'
      end

      # Public-facing label — keeps the wire `api_type` as `user_rule`
      # (preference column is `user_ids`) so existing data stays valid,
      # but every UI surface reads "Customer rule".
      def self.human_name
        'Customer rule'
      end

      def self.superseded?
        true
      end
    end
  end
end
