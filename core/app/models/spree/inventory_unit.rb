module Spree
  class InventoryUnit < Spree::Base
    with_options inverse_of: :inventory_units do
      belongs_to :variant, class_name: 'Spree::Variant'
      belongs_to :order, class_name: 'Spree::Order'
      belongs_to :shipment, class_name: 'Spree::Shipment', touch: true, optional: true
      belongs_to :return_authorization, class_name: 'Spree::ReturnAuthorization'
      belongs_to :line_item, class_name: 'Spree::LineItem'
    end

    has_many :return_items, inverse_of: :inventory_unit
    belongs_to :original_return_item, class_name: 'Spree::ReturnItem'

    scope :backordered, -> { where state: 'backordered' }
    scope :on_hand, -> { where state: 'on_hand' }
    scope :on_hand_or_backordered, -> { where state: ['backordered', 'on_hand'] }
    scope :shipped, -> { where state: 'shipped' }
    scope :returned, -> { where state: 'returned' }
    scope :backordered_per_variant, ->(stock_item) do
      includes(:shipment, :order).
        where.not(spree_shipments: { state: 'canceled' }).
        where(variant_id: stock_item.variant_id).
        where.not(spree_orders: { completed_at: nil }).
        backordered.order('spree_orders.completed_at ASC')
    end

    validates :quantity, numericality: { greater_than: 0 }

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :on_hand do
      event :fill_backorder do
        transition to: :on_hand, from: :backordered
      end
      after_transition on: :fill_backorder, do: :fulfill_order

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

    def self.finalize_units!
      update_all(pending: false, updated_at: Time.current)
    end

    def find_stock_item
      Spree::StockItem.where(stock_location_id: shipment.stock_location_id,
                             variant_id: variant_id).first
    end

    def self.split(original_inventory_unit, extract_quantity)
      split = original_inventory_unit.dup
      split.quantity = extract_quantity
      original_inventory_unit.quantity -= extract_quantity
      split
    end

    # This will fail if extract >= available_quantity
    def split_inventory!(extract_quantity)
      split = self.class.split(self, extract_quantity)
      transaction do
        split.save!
        save!
      end
      split
    end

    def extract_singular_inventory!
      split_inventory!(1)
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    def current_or_new_return_item
      Spree::ReturnItem.from_inventory_unit(self)
    end

    def additional_tax_total
      line_item.additional_tax_total * percentage_of_line_item
    end

    def included_tax_total
      line_item.included_tax_total * percentage_of_line_item
    end

    def required_quantity
      return @required_quantity unless @required_quantity.nil?

      @required_quantity = if exchanged_unit?
                             original_return_item.return_quantity
                           else
                             line_item.quantity
                           end
    end

    def exchanged_unit?
      original_return_item_id?
    end

    private

    def allow_ship?
      on_hand?
    end

    def fulfill_order
      reload
      order.fulfill!
    end

    def percentage_of_line_item
      quantity / BigDecimal.new(line_item.quantity)
    end

    def current_return_item
      return_items.not_cancelled.first
    end
  end
end
