class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  belongs_to :shipment
  belongs_to :return_authorization

  named_scope :retrieve_on_hand, lambda {|variant, quantity| {:conditions => ["state = 'on_hand' AND variant_id = ?", variant], :limit => quantity}}

  # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'on_hand' do
    event :fill_backorder do
      transition :to => 'sold', :from => 'backordered'
    end
    event :ship do
      transition :to => 'shipped', :if => :allow_ship? #, :from => 'sold'
    end
    # TODO: add backorder state and relevant transitions
  end

  # destroy the specified number of on hand inventory units
  def self.destroy_on_hand(variant, quantity)
    inventory = self.retrieve_on_hand(variant, quantity)
    inventory.each do |unit|
      unit.destroy
    end
  end

  # create the specified number of on hand inventory units
  def self.create_on_hand(variant, quantity)
    quantity.times do
      self.create(:variant => variant, :state => 'on_hand')
    end
  end

  # grab the appropriate units from inventory, mark as sold and associate with the order
  def self.sell_units(order)

    # we should not already have inventory associated with the order at this point but we should clear to be safe (#1394)
    order.inventory_units.destroy_all

    out_of_stock_items = []
    order.line_items.each do |line_item|
      variant = line_item.variant
      quantity = line_item.quantity

      out_of_stock_items.concat create_units(order, variant, quantity)
    end
    out_of_stock_items
  end

  def self.adjust_units(order)
    units_by_variant = order.inventory_units.group_by(&:variant_id)
    out_of_stock_items = []

    #check line items quantities match
    order.line_items.each do |line_item|
      variant = line_item.variant
      quantity = line_item.quantity
      unit_count = units_by_variant.key?(variant.id) ? units_by_variant[variant.id].size : 0

      if unit_count < quantity
        out_of_stock_items.concat create_units(order, variant, (quantity - unit_count))
      elsif  unit_count > quantity
        (unit_count - quantity).times do
          inventory_unit = units_by_variant[variant.id].pop
          inventory_unit.restock!
        end
      end

      #remove it from hash as it's up-to-date
      units_by_variant.delete(variant.id)
    end

    #check for deleted line items (if theres anything left in units_by_variant its' extra)
    units_by_variant.each do |variant_id, units|
      units.each {|unit| unit.restock!}
    end

    out_of_stock_items
  end

  def can_restock?
    %w(sold shipped backordered).include?(state)
  end

  def restock!
    variant.update_attribute(:count_on_hand, variant.count_on_hand + 1) if Spree::Config[:track_inventory_levels] && !backordered?
    delete
  end

  # find the specified quantity of units with the specified status
  def self.find_by_status(variant, quantity, status)
    variant.inventory_units.find(:all,
                                 :conditions => ['status = ? ', status],
                                 :limit => quantity)
  end

  private
  def allow_ship?
    Spree::Config[:allow_backorder_shipping] || (state == 'ready_to_ship')
  end

  def self.create_units(order, variant, quantity)
    out_of_stock_items = []

    if Spree::Config[:track_inventory_levels]
      # mark all of these units as sold and associate them with this order
      remaining_quantity = variant.count_on_hand - quantity
      if (remaining_quantity >= 0)
        quantity.times do
          order.inventory_units.create(:variant => variant, :state => "sold")
        end
        variant.update_attribute(:count_on_hand, remaining_quantity)
      else
        (quantity + remaining_quantity).times do
          order.inventory_units.create(:variant => variant, :state => "sold")
        end
        if Spree::Config[:allow_backorders]
          (-remaining_quantity).times do
            order.inventory_units.create(:variant => variant, :state => "backordered")
          end
        else
          line_item.update_attribute(:quantity, quantity + remaining_quantity)
          out_of_stock_items << {:line_item => line_item, :count => -remaining_quantity}
        end
        variant.update_attribute(:count_on_hand, 0)
      end
    else
      # not tracking stock levels, so just create all inventory_units as sold (for shipping purposes)
      quantity.times do
        order.inventory_units.create(:variant => variant, :state => "sold")
      end
    end
    out_of_stock_items
  end

end
