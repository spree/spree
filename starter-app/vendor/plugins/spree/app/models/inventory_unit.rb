class InventoryUnit < ActiveRecord::Base
  belongs_to :variant
  belongs_to :order
  validates_presence_of :status
  
  enumerable_constant :status, {:constants => INVENTORY_STATES, :no_validation => true}
  
  # destory the specified number of on hand inventory units 
  def self.destroy_on_hand(variant, quantity)
    @inventory = variant.inventory_units.find(:all, 
                                              :conditions => ['status = ? ', InventoryUnit::Status::ON_HAND], 
                                              :limit => quantity.abs)
    @inventory.each do |unit|
      unit.destroy
    end                                          
  end
  
  # destory the specified number of on hand inventory units
  def self.create_on_hand(variant, quantity)
    quantity.times do
      self.create(:variant => variant, :status => InventoryUnit::Status::ON_HAND)
    end
  end
end