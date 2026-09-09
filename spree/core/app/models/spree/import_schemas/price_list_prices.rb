module Spree
  module ImportSchemas
    class PriceListPrices < Spree::ImportSchema
      FIELDS = [
        { name: 'sku', label: 'SKU', required: true },
        { name: 'currency', label: 'Currency' },
        { name: 'min_quantity', label: 'Minimum quantity' },
        { name: 'price', label: 'Price', required: true },
        { name: 'compare_at_price', label: 'Compare at Price' }
      ].freeze
    end
  end
end
