module Spree
  class InventoryUnit < ActiveRecord::Base
    belongs_to :variant
    belongs_to :order
    belongs_to :shipment
    belongs_to :return_authorization

    scope :backordered, lambda { where(:state => 'backordered') }
    scope :shipped, lambda { where(:state => 'shipped') }

    attr_accessible :shipment

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine :initial => 'on_hand' do
      event :fill_backorder do
        transition :to => 'sold', :from => 'backordered'
      end
      after_transition :on => :fill_backorder, :do => :update_order

      event :ship do
        transition :to => 'shipped', :if => :allow_ship?
      end
      event :return do
        transition :to => 'returned', :from => 'shipped'
      end
      after_transition :to => 'returned', :do => :restock_variant
    end

    def self.backordered_for_stock_item(stock_item)
      stock_locations_table = Spree::StockLocation.table_name
      joins(:shipment => :stock_location).
      where("#{stock_locations_table}.id = ?", stock_item.stock_location_id).
      where("#{table_name}.variant_id = ?", stock_item.variant_id).
      where("spree_shipments.state != 'canceled'").
      where(:state => "backordered").order("created_at ASC")
    end

    # manages both variant.count_on_hand and inventory unit creation
    #
    def self.increase(order, stock_item, quantity)
      back_order = stock_item.determine_backorder(quantity)
      sold = quantity - back_order

      #set on_hand if configured
      if self.track_levels?(stock_item.variant)
        Spree::StockMovement.create!(stock_item: stock_item, quantity: -quantity)
      end

      #create units if configured
      if Spree::Config[:create_inventory_units]
        create_units(order, stock_item.variant, sold, back_order)
      end
    end

    def self.decrease(order, stock_item, quantity)
      if self.track_levels?(stock_item.variant)
        Spree::StockMovement.create!(stock_item: stock_item, quantity: quantity)
      end

      if Spree::Config[:create_inventory_units]
        destroy_units(order, stock_item.variant, quantity)
      end
    end

    def self.track_levels?(variant)
      Spree::Config[:track_inventory_levels]
    end

    def self.finalize_units!(inventory_units)
      inventory_units.map { |iu| iu.update_column(:pending, false) }
    end

    def find_stock_item
      Spree::StockItem.where({:stock_location_id => self.shipment.stock_location_id, :variant_id => variant_id}).first
    end

    private
      def allow_ship?
        Spree::Config[:allow_backorder_shipping] || self.sold?
      end

      def self.destroy_units(order, variant, quantity)
        variant_units = order.inventory_units.group_by(&:variant_id)
        return unless variant_units.include? variant.id

        variant_units = variant_units[variant.id].reject do |variant_unit|
          variant_unit.state == 'shipped'
        end.sort_by(&:state)

        quantity.times do
          inventory_unit = variant_units.shift
          inventory_unit.destroy
        end
      end

      def self.create_units(order, variant, sold, back_order)
        return if back_order > 0 && !Spree::Config[:allow_backorders]

        shipment = order.shipments.detect { |shipment| !shipment.shipped? }

        sold.times { order.inventory_units.create({:variant => variant, :state => 'sold', :shipment => shipment}, :without_protection => true) }
        back_order.times { order.inventory_units.create({:variant => variant, :state => 'backordered', :shipment => shipment}, :without_protection => true) }
      end

      def update_order
        order.update!
      end

      def restock_variant
        if self.class.track_levels?(variant)
          variant.on_hand += 1
          variant.save
        end
      end
  end
end
