module Spree
  class InventoryUnit < ActiveRecord::Base
    belongs_to :variant
    belongs_to :order
    belongs_to :shipment
    belongs_to :return_authorization

    scope :backordered, lambda { where(:state => 'backordered') }
    scope :shipped, lambda { where(:state => 'shipped') }

    def self.backorder
      warn "[SPREE] Spree::InventoryUnit.backorder will be deprecated in Spree 1.3. Please use Spree::Product.backordered instead."
      backordered
    end

    attr_accessible :shipment

    # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine :initial => 'on_hand' do
      event :fill_backorder do
        transition :to => 'sold', :from => 'backordered'
      end
      event :ship do
        transition :to => 'shipped', :if => :allow_ship?
      end
      event :return do
        transition :to => 'returned', :from => 'shipped'
      end

      after_transition :on => :fill_backorder, :do => :update_order
      after_transition :to => 'returned', :do => :restock_variant
    end

    # Assigns inventory to a newly completed order.
    # Should only be called once during the life-cycle of an order, on transition to completed.
    #
    def self.assign_opening_inventory(order)
      return [] unless order.completed?

      #increase inventory to meet initial requirements
      order.line_items.each do |line_item|
        increase(order, line_item.variant, line_item.quantity)
      end
    end

    # manages both variant.count_on_hand and inventory unit creation
    #
    def self.increase(order, variant, quantity)
      back_order = determine_backorder(order, variant, quantity)
      sold = quantity - back_order

      #set on_hand if configured
      if Spree::Config[:track_inventory_levels]
        variant.decrement!(:count_on_hand, quantity)
      end

      #create units if configured
      if Spree::Config[:create_inventory_units]
        create_units(order, variant, sold, back_order)
      end
    end

    def self.decrease(order, variant, quantity)
      if Spree::Config[:track_inventory_levels]
        variant.increment!(:count_on_hand, quantity)
      end

      if Spree::Config[:create_inventory_units]
        destroy_units(order, variant, quantity)
      end
    end

    private
      def allow_ship?
        Spree::Config[:allow_backorder_shipping] || self.sold?
      end

      def self.determine_backorder(order, variant, quantity)
        if variant.on_hand == 0
          quantity
        elsif variant.on_hand.present? and variant.on_hand < quantity
          quantity - (variant.on_hand < 0 ? 0 : variant.on_hand)
        else
          0
        end
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
        if Spree::Config[:track_inventory_levels]
          variant.on_hand += 1
          variant.save
        end
      end
  end
end
