module Spree
  class InventoryUnit < Spree::Base
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :inventory_units
    belongs_to :order, class_name: "Spree::Order", inverse_of: :inventory_units
    belongs_to :shipment, class_name: "Spree::Shipment", touch: true, inverse_of: :inventory_units
    belongs_to :return_authorization, class_name: "Spree::ReturnAuthorization"
    belongs_to :line_item, class_name: "Spree::LineItem", inverse_of: :inventory_units

    has_many :return_items, inverse_of: :inventory_unit

    scope :backordered, -> { where state: 'backordered' }
    scope :on_hand, -> { where state: 'on_hand' }
    scope :shipped, -> { where state: 'shipped' }
    scope :returned, -> { where state: 'returned' }
    scope :backordered_per_variant, ->(stock_item) do
      includes(:shipment, :order)
        .where("spree_shipments.state != 'canceled'").references(:shipment)
        .where(variant_id: stock_item.variant_id)
        .where('spree_orders.completed_at is not null')
        .backordered.order("spree_orders.completed_at ASC")
    end

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :on_hand do
      event :fill_backorder do
        transition to: :on_hand, from: :backordered
      end
      after_transition on: :fill_backorder, do: :update_order

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

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    def current_or_new_return_item
      current_return_item || Spree::ReturnItem.new(inventory_unit: self,
                                                   pre_tax_amount: pre_tax_amount)
    end

    def pre_tax_amount
      weighted_order_adjustment_amount + weighted_line_item_pre_tax_amount
    end

    def additional_tax_total
      line_item.additional_tax_total * percentage_of_line_item
    end

    def included_tax_total
      line_item.included_tax_total * percentage_of_line_item
    end

    private

      def allow_ship?
        self.on_hand?
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

      def current_return_item
        return_items.not_cancelled.first
      end
  end
end
