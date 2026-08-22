module Spree
  module ImportSchemas
    class Prices < Spree::ImportSchema
      FIELDS = [
        { name: 'sku', label: 'SKU' },
        { name: 'external_id', label: 'External ID' },
        { name: 'external_system', label: 'External System' },
        { name: 'currency', label: 'Currency', required: true },
        { name: 'amount', label: 'Amount' },
        { name: 'compare_at_amount', label: 'Compare At Amount' },
        { name: 'price_list', label: 'Price List' }
      ].freeze
    end
  end
end
