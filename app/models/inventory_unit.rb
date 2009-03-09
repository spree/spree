class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  
  named_scope :retrieve_on_hand, lambda {|variant, quantity| {:conditions => ["state = 'on_hand' AND variant_id = ?", variant], :limit => quantity}}

  # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'on_hand' do    
    event :sell do
      transition :to => 'sold', :from => 'on_hand'
    end
    event :fill_backorder do
      transition :to => 'sold', :from => 'backordered'
    end
    event :ship do
      transition :to => 'shipped', :if => :allow_ship? #, :from => 'sold'
    end
    event :restock do
      transition :to => 'on_hand', :from => %w(sold shipped)
    end
    # TODO: add backorder state and relevant transitions
  end
  
  # destory the specified number of on hand inventory units 
  def self.destroy_on_hand(variant, quantity)
    inventory = self.retrieve_on_hand(variant, quantity)
    inventory.each do |unit|
      unit.destroy
    end                                          
  end
  
  # destory the specified number of on hand inventory units
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
      # retrieve the requested number of on hand units (or as many as possible) - note: optimistic locking used here
      on_hand = self.retrieve_on_hand(variant, quantity)
      # mark all of these units as sold and associate them with this order 
      on_hand.each do |unit|
        unit.sell!
      end
      # right now we always allow back ordering
      backorder = quantity - on_hand.size
      backorder.times do 
        order.inventory_units.create(:variant => variant, :state => "backordered")
      end
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
    state == 'ready_to_ship' || Spree::Config[:allow_backorder_shipping]
  end
  
end