module Spree
  class InventoryUnit < ActiveRecord::Base
    belongs_to :variant
    belongs_to :order
    belongs_to :shipment
    belongs_to :return_authorization

    scope :backordered, -> { where(state: 'backordered') }
    scope :shipped, -> { where(state: 'shipped') }

    attr_accessible :shipment, :variant_id

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: 'on_hand' do
      event :fill_backorder do
        transition to: 'on_hand', from: 'backordered'
      end
      after_transition on: :fill_backorder, do: :update_order

      event :ship do
        transition to: 'shipped', if: :allow_ship?
      end
      event :return do
        transition to: 'returned', from: 'shipped'
      end
    end

    def self.backordered_for_stock_item(stock_item)
      stock_locations_table = Spree::StockLocation.table_name
      joins(shipment: :stock_location).
      where("#{stock_locations_table}.id = ?", stock_item.stock_location_id).
      where("#{table_name}.variant_id = ?", stock_item.variant_id).
      where("spree_shipments.state != 'canceled'").
      where(state: "backordered").order("created_at ASC")
    end

    def self.finalize_units!(inventory_units)
      inventory_units.map { |iu| iu.update_column(:pending, false) }
    end

    def find_stock_item
      Spree::StockItem.where({stock_location_id: self.shipment.stock_location_id, variant_id: variant_id}).first
    end

    private
      def allow_ship?
        Spree::Config[:allow_backorder_shipping] || self.on_hand?
      end

      def update_order
        order.update!
      end
  end
end
