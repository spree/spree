module Spree
  module PriceRules
    class StoreRule < Spree::PriceRule
      preference :store_ids, :array, default: []

      def applicable?(context)
        return false unless context.store
        return true if preferred_store_ids.empty?

        preferred_store_ids.include?(context.store.id)
      end

      def self.description
        'Apply pricing based on which store the customer is shopping in'
      end
    end
  end
end
