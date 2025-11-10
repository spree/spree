module Spree
  module PriceRules
    class UserRule < Spree::PriceRule
      preference :user_ids, :array, default: []

      def applicable?(context)
        return false unless context.user
        return true if preferred_user_ids.empty?

        preferred_user_ids.include?(context.user.id)
      end

      def self.description
        'Apply pricing to specific users'
      end
    end
  end
end
