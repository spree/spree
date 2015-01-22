module Spree
  class InventoryUnit < Spree::Base
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :inventory_units
    belongs_to :order, class_name: "Spree::Order", inverse_of: :inventory_units
    belongs_to :shipment, class_name: "Spree::Shipment", touch: true, inverse_of: :inventory_units
    belongs_to :return_authorization, class_name: "Spree::ReturnAuthorization", inverse_of: :inventory_units
    belongs_to :line_item, class_name: "Spree::LineItem", inverse_of: :inventory_units

    has_many :return_items, inverse_of: :inventory_unit
    has_one :original_return_item, class_name: "Spree::ReturnItem", foreign_key: :exchange_inventory_unit_id

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

    def additional_tax_total
      line_item.additional_tax_total * percentage_of_line_item
    end

    def current_or_new_return_item
      Spree::ReturnItem.from_inventory_unit(self)
    end

    def find_stock_item
      Spree::StockItem.where(stock_location_id: shipment.stock_location_id,
      variant_id: variant_id).first
    end

    def included_tax_total
      line_item.included_tax_total * percentage_of_line_item
    end

    def returned?
      current_state == 'returned'
    end

    def state_machine
      @state_machine ||= StateMachines::InventoryUnit.new(self)
    end
    delegate :current_state, :transition_to, :transition_to!, :trigger!, to: :state_machine

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    private

      def self.initial_state
        :on_hand
      end

      def allow_ship?
        on_hand?
      end

      def current_return_item
        return_items.not_cancelled.first
      end

      def fulfill_order
        self.reload
        order.fulfill!
      end

      def percentage_of_line_item
        1 / BigDecimal.new(line_item.quantity)
      end

  end
end
