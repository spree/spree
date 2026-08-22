module Spree
  module ImportSchemas
    class StockLevels < Spree::ImportSchema
      # A feed identifies the shelf by SKU and location name, which is what a
      # warehouse export actually contains — prefixed ids are Spree's own and
      # a warehouse has no reason to know them. external_id addresses a variant
      # by the key the feeding system holds, paired with external_system.
      FIELDS = [
        { name: 'sku', label: 'SKU' },
        { name: 'external_id', label: 'External ID' },
        { name: 'external_system', label: 'External System' },
        { name: 'stock_location', label: 'Stock Location', required: true },
        { name: 'count_on_hand', label: 'Count On Hand' },
        { name: 'adjustment', label: 'Adjustment' },
        { name: 'backorderable', label: 'Backorderable' }
      ].freeze
    end
  end
end
