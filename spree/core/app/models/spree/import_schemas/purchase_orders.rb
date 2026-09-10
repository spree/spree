module Spree
  module ImportSchemas
    # One row per line; rows sharing a reference become one draft order.
    class PurchaseOrders < Spree::ImportSchema
      FIELDS = [
        { name: 'reference', label: 'Reference', required: true },
        { name: 'supplier', label: 'Supplier', required: true },
        { name: 'destination', label: 'Destination', required: true },
        { name: 'sku', label: 'SKU', required: true },
        { name: 'quantity', label: 'Quantity', required: true },
        { name: 'unit_cost', label: 'Unit cost', required: true },
        { name: 'currency', label: 'Currency' },
        { name: 'expected_at', label: 'Expected on' },
        { name: 'cancel_by', label: 'Cancel by' },
        { name: 'notes', label: 'Notes' }
      ].freeze
    end
  end
end
