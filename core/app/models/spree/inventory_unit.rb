module Spree
  class InventoryUnit < Spree::Base
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :inventory_units
    belongs_to :shipment, class_name: "Spree::Shipment", touch: true, inverse_of: :inventory_units
    belongs_to :return_authorization, class_name: "Spree::ReturnAuthorization"
    belongs_to :line_item, class_name: "Spree::LineItem", inverse_of: :inventory_units
    delegate :order, to: :shipment

    has_many :return_items, inverse_of: :inventory_unit

    scope :backordered, -> { where state: 'backordered' }
    scope :on_hand, -> { where state: 'on_hand' }
    scope :shipped, -> { where state: 'shipped' }
    scope :returned, -> { where state: 'returned' }
    scope :backordered_per_variant, ->(stock_item) do
      includes(shipment: :order)
        .where("spree_shipments.state != 'canceled'").references(:shipment)
        .where(variant_id: stock_item.variant_id)
        .where('spree_orders.completed_at is not null')
        .backordered.order("spree_orders.completed_at ASC")
    end

    validates :quantity, numericality: { greater_than_or_equal_to: 1, only_integer: true }

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :on_hand do
      state :backordered

      event :ship do
        transition to: :shipped, if: :allow_ship?
      end

      event :return do
        transition to: :returned, from: :shipped
      end
    end

    # This was refactored from a simpler query because the previous implementation
    # led to issues once users tried to modify the objects returned. That's due
    # to ActiveRecord `joins(shipment: :stock_location)` only returning readonly
    # objects
    #
    # Returns an array of backordered inventory units as per a given stock item
    def self.backordered_for_stock_item(stock_item)
      backordered_per_variant(stock_item).select do |unit|
        unit.shipment.stock_location == stock_item.stock_location
      end
    end

    def self.finalize_units!(inventory_units)
      inventory_units.map do |iu|
        iu.update_columns(
          pending: false,
          updated_at: Time.now,
        )
      end
    end

    def find_stock_item
      Spree::StockItem.where(stock_location_id: shipment.stock_location_id,
        variant_id: variant_id).first
    end

    def remove(count)
      count = quantity if count > quantity

      self.quantity -= count
      if quantity == 0
        destroy
      else
        save!
      end

      count
    end

    # Splits `count` units into a new duplicate (other than quantity) record.
    # The new record is yielded before saving, and the saved record is
    # returned.
    def split!(count)
      raise ArgumentError if count <= 0
      count = remove(count)
      InventoryUnit.create! do |unit|
        unit.quantity = count
        unit.variant_id = variant_id
        unit.line_item_id = line_item_id
        unit.shipment_id = shipment_id
        unit.state = state
        yield unit
      end
    end

    def fill_backorders(count)
      raise "item not backordered" unless backordered?
      return if count.zero?
      split!(count) do |unit|
        unit.state = 'on_hand'
      end.quantity
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    def rounded_pre_tax_amount
      (weighted_order_adjustment_amount + weighted_line_item_pre_tax_amount).round(2, :down)
    end

    private

      def allow_ship?
        Spree::Config[:allow_backorder_shipping] || self.on_hand?
      end

      def update_order
        order.update!
      end

      def weighted_line_item_pre_tax_amount
        line_item.pre_tax_amount * percentage_of_line_item
      end

      def weighted_order_adjustment_amount
        order.adjustments.eligible.non_tax.sum(:amount) * percentage_of_order_total
      end

      def percentage_of_order_total
        return 0.0 if order.pre_tax_item_amount.zero?
        weighted_line_item_pre_tax_amount / order.pre_tax_item_amount
      end

      def percentage_of_line_item
        1 / BigDecimal.new(line_item.quantity)
      end
  end
end

