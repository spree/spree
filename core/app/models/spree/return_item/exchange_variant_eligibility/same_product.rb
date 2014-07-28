module Spree
  module ReturnItem::ExchangeVariantEligibility
    class SameProduct

      def self.eligible_variants(variant)
        Spree::Variant.where.not(id: variant.id).where(product_id: variant.product_id, is_master: false)
      end
    end
  end
end
