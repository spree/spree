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

    out_of_stock_items = []

    #increase inventory to meet initial requirements
    order.line_items.each do |line_item|
      out_of_stock_items.concat increase(order, line_item.variant, line_item.quantity)
    end

    out_of_stock_items
  end

  # manages both variant.count_on_hand and inventory unit creation
  #
  def self.increase(order, variant, quantity)
    # calculate number of sold vs. backordered units
    if variant.on_hand == 0
      back_order = quantity
      sold = 0
    elsif variant.on_hand.present? and variant.on_hand < quantity
      back_order = quantity - (variant.on_hand < 0 ? 0 : variant.on_hand)
      sold = quantity - back_order
    else
      back_order = 0
      sold = quantity
    end

    #set on_hand if configured
    if Spree::Config[:track_inventory_levels]
      variant.decrement!(:count_on_hand, quantity)
    end

    #create units if configured, returning any backorderd variants with count
    out_of_stock_items = []
    if Spree::Config[:create_inventory_units]
      out_of_stock_items = create_units(order, variant, sold, back_order)
    end
    out_of_stock_items
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
    variant.inventory_units.find(:all,
                                 :conditions => ['status = ? ', status],
                                 :limit => quantity)
  end

  private
  def allow_ship?
    Spree::Config[:allow_backorder_shipping] || self.sold?
  end

  def self.destroy_units(order, variant, quantity)
    variant_units = order.inventory_units.group_by(&:variant_id)[variant.id].sort_by(&:state)

    quantity.times do
      inventory_unit = variant_units.shift
      inventory_unit.destroy
    end
  end

  def self.create_units(order, variant, sold, back_order)
    shipment = order.shipments.detect {|shipment| !shipment.shipped? }

    sold.times do
      order.inventory_units.create(:variant => variant, :state => "sold", :shipment => shipment)
    end

    if Spree::Config[:allow_backorders]
      back_order.times { order.inventory_units.create(:variant => variant, :state => "backordered", :shipment => shipment) }
    end

    back_order == 0 ? [] : [{:variant => variant, :count => back_order}]
  end

  def update_order
    self.order.update!
  end

  def restock_variant
    self.variant.on_hand = (self.variant.on_hand + 1)
    self.variant.save
  end

end
