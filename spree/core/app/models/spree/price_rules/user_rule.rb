module Spree
  module PriceRules
    class UserRule < Spree::PriceRule
      preference :user_ids, :array, default: []

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
    end
  end
end
