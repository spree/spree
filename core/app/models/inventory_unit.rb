class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  belongs_to :shipment
  belongs_to :return_authorization

  scope :backorder, where(:state => 'backordered')

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

  # method deprecated in favour of adjust_units (which creates & destroys units as needed).
  def self.sell_units(order)
    warn "[DEPRECATION] `InventoryUnits#sell_units` is deprecated.  Please use `InventoryUnits#assign_opening_inventory` instead. (called from #{caller[0]})"
    self.adjust_units(order)
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

  # find the specified quantity of units with the specified status
  def self.find_by_status(variant, quantity, status)
    variant.inventory_units.where(:status => status).limit(quantity)
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
    variant_units = order.inventory_units.group_by(&:variant_id)[variant.id].sort_by(&:state)

    quantity.times do
      inventory_unit = variant_units.shift
      inventory_unit.destroy
    end
  end

  def self.create_units(order, variant, sold, back_order)
    if back_order > 0 && !Spree::Config[:allow_backorders]
      raise "Cannot request back orders when backordering is disabled"
    end

    shipment = order.shipments.detect {|shipment| !shipment.shipped? }

    sold.times { order.inventory_units.create(:variant => variant, :state => "sold", :shipment => shipment) }
    back_order.times { order.inventory_units.create(:variant => variant, :state => "backordered", :shipment => shipment) }
  end

  def update_order
    self.order.update!
  end

  def restock_variant
    self.variant.on_hand = (self.variant.on_hand + 1)
    self.variant.save
  end

end
