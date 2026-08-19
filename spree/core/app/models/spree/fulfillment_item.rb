module Spree
  class FulfillmentItem < Spree.base_class
    has_prefix_id :fi

    extend Spree::DisplayMoney

    with_options inverse_of: :fulfillment_items do
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
      # Optional because cart-phase items have no order yet — their owner is
      # reached through the fulfillment; order_id arrives at completion.
      belongs_to :order, class_name: 'Spree::Order', optional: true
      belongs_to :fulfillment, class_name: 'Spree::Fulfillment', touch: true, optional: true
      has_many :return_line_items, class_name: 'Spree::ReturnLineItem', inverse_of: :fulfillment_item
      has_many :returns, class_name: 'Spree::Return', through: :return_line_items
      belongs_to :line_item, class_name: 'Spree::LineItem'
    end

    scope :backordered, -> { where status: 'backordered' }
    scope :on_hand, -> { where status: 'on_hand' }
    scope :on_hand_or_backordered, -> { where status: ['backordered', 'on_hand'] }
    scope :shipped, -> { where status: 'shipped' }
    scope :returned, -> { where status: 'returned' }
    scope :backordered_per_variant, ->(stock_level) do
      includes(:fulfillment, :order).
        where.not(Spree::Fulfillment.table_name => { status: 'canceled' }).
        where(variant_id: stock_level.variant_id).
        where.not(spree_orders: { completed_at: nil }).
        backordered.order('spree_orders.completed_at ASC')
    end

    # Legacy names — removed in 6.1.
    belongs_to :shipment, class_name: 'Spree::Fulfillment', foreign_key: :fulfillment_id, optional: true, touch: true, deprecated: true
    alias_attribute :shipment_id, :fulfillment_id
    # @deprecated the column is +status+ since 6.0
    alias_attribute :state, :status

    validates :quantity, numericality: { greater_than: 0 }

    money_methods :charged_amount

    # No state machine — the moves are driven by the Spree::Fulfillments
    # workflows and by Spree::StockLevel when stock arrives for a backorder
    # (docs/plans/6.0-service-workflows.md). Filling a backorder used to
    # recalculate the whole order from a transition callback, once per item;
    # the callers now do that themselves, after the loop.
    include Spree::HasStatus
    has_status :on_hand, :backordered, :shipped, :returned, default: :on_hand

    # Marks the item dispatched. Normally only stock in hand can leave, but a
    # forced dispatch ships a backordered item too: departure is a physical
    # fact, and a parcel the merchant has already handed over is recorded
    # whatever the shelf says. An item that has already shipped or been
    # returned is left alone.
    #
    # @param force [Boolean] dispatch a backordered item as well
    # @return [Boolean] whether the item moved
    def ship!(force: false)
      return false unless on_hand? || (force && backordered?)

      update!(status: 'shipped')
      true
    end

    # Stock arrived for a backordered item. Callers recalculate the order once
    # afterwards; this only moves the row.
    #
    # @return [Boolean] whether the item moved
    def fill_backorder!
      return false unless backordered?

      update!(status: 'on_hand')
      true
    end
    alias fill_backorder fill_backorder!

    # @deprecated Write the status — removed in 6.1. `return` was a state
    #   machine event name and could never be called as written (it parses as
    #   the keyword), so this exists only for `send(:return!)`-style callers.
    def return!
      Spree::Deprecation.warn('Spree::FulfillmentItem#return! is deprecated and will be removed in Spree 6.1. Write the status instead.')
      return false unless shipped?

      update!(status: 'returned')
      true
    end

    # This was refactored from a simpler query because the previous implementation
    # led to issues once users tried to modify the objects returned. That's due
    # to ActiveRecord `joins(shipment: :stock_location)` only returning readonly
    # objects
    #
    # Returns an array of backordered inventory units as per a given stock item
    def self.backordered_for_stock_level(stock_level)
      backordered_per_variant(stock_level).select do |unit|
        unit.fulfillment.stock_location == stock_level.stock_location
      end
    end

    def self.finalize_units!
      update_all(pending: false, updated_at: Time.current)
    end

    def find_stock_level
      fulfillment.stock_location.stock_level_or_create(variant)
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

    def additional_tax_total
      line_item.additional_tax_total * percentage_of_line_item
    end

    def included_tax_total
      line_item.included_tax_total * percentage_of_line_item
    end

    def required_quantity
      @required_quantity ||= line_item.quantity
    end

    def charged_amount
      percentage_of_line_item * line_item.pre_tax_amount
    end

    def percentage_of_line_item
      quantity / BigDecimal(line_item.quantity)
    end
  end
end
