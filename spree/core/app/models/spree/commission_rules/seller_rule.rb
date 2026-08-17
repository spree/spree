# frozen_string_literal: true

module Spree
  module CommissionRules
    # Charge this rate only when the seller is one of these.
    class SellerRule < Spree::CommissionRule
      # Ids are checked against the rate's own store on write, so a rule can
      # never be pointed at another marketplace's seller — and the client is
      # told, rather than having the id quietly dropped.
      preference :seller_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Seller,
                   scope: ->(rule) { rule.store.sellers }
                 )

      # @return [Array<Spree::Seller>]
      def sellers
        return [] if preferred_seller_ids.blank?

        Spree::Seller.where(id: preferred_seller_ids)
      end

      def applicable?(context)
        return false if context.seller.nil?
        # A rule naming nobody narrows nothing, which is what a half-filled
        # form leaves behind — it must not silently charge every seller.
        return false if preferred_seller_ids.blank?

        preferred_seller_ids.map(&:to_s).include?(context.seller.id.to_s)
      end
    end
  end
end
