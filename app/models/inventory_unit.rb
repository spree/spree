class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  belongs_to :shipment
  
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
    order.line_items.each do |line_item|
      variant = line_item.variant
      quantity = line_item.quantity
      
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
        # right now we always allow back ordering
        (-remaining_quantity).times do 
          order.inventory_units.create(:variant => variant, :state => "backordered")
        end
        variant.update_attribute(:count_on_hand, 0)
      end  
    end
  end
  
  def can_restock?
    %w(sold shipped).include?(state)
  end
  
  def restock!  
    variant.update_attribute(:count_on_hand, variant.count_on_hand + 1)
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
  
end
