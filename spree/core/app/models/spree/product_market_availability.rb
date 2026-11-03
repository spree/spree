module Spree
  # A market named by its product's market availability: excluded from it
  # under +all_except+, one of the only markets it is sold in under +only+
  # (docs/plans/6.1-product-market-availability.md).
  class ProductMarketAvailability < Spree.base_class
    belongs_to :product, class_name: 'Spree::Product', touch: true
    belongs_to :market, class_name: 'Spree::Market'

    validates :market_id, uniqueness: { scope: [:product_id, *spree_base_uniqueness_scope] }
    validate :market_belongs_to_product_store

    private

    def market_belongs_to_product_store
      return if market.nil? || product.nil? || market.store_id == product.store_id

      errors.add(:market, :invalid)
    end
  end
end
