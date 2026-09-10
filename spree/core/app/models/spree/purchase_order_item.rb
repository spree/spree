module Spree
  # One SKU on a purchase order: how many were ordered, how many have arrived,
  # and what the merchant agreed to pay per unit.
  class PurchaseOrderItem < Spree.base_class
    has_prefix_id :poi

    include Spree::ReceivableItem

    expects_quantity_in :quantity_ordered

    belongs_to :purchase_order, class_name: 'Spree::PurchaseOrder', inverse_of: :items, touch: true

    validates :quantity_ordered, numericality: { greater_than: 0, only_integer: true }
    validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }
    validates :variant_id, uniqueness: { scope: :purchase_order_id }

    delegate :currency, to: :purchase_order, allow_nil: true

    self.whitelisted_ransackable_attributes = %w[variant_id quantity_ordered quantity_received quantity_rejected unit_cost]
    self.whitelisted_ransackable_associations = %w[variant]

    # What the whole line costs at the agreed unit price. Ordered rather than
    # received quantity: this is what the supplier will invoice.
    #
    # @return [BigDecimal]
    def total_cost
      unit_cost.to_d * quantity_ordered.to_i
    end

    # @return [Spree::Money]
    def display_unit_cost
      Spree::Money.new(unit_cost, currency: currency)
    end

    # @return [Spree::Money]
    def display_total_cost
      Spree::Money.new(total_cost, currency: currency)
    end
  end
end
