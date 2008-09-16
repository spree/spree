class Variant < ActiveRecord::Base
  after_update :adjust_inventory
  
  belongs_to :product
  has_many :inventory_units
  has_and_belongs_to_many :option_values
  
  validates_presence_of :product
  validate :check_price

  def on_hand
    inventory_units.with_state("on_hand").size
  end

  def on_hand=(new_level)
    @new_level = new_level
  end
  
  def in_stock
    on_hand > 0
  end

  private

    def adjust_inventory    
      return unless @new_level && @new_level.is_integer?    
      @new_level = @new_level.to_i
      # don't allow negative on_hand inventory
      return if @new_level < 0
      adjustment = @new_level - on_hand
      if adjustment > 0
        InventoryUnit.create_on_hand(self, adjustment)
        reload
      elsif adjustment < 0
        InventoryUnit.destroy_on_hand(self, adjustment.abs)
        reload
      end      
    end
  
    # if no variant price has been set, set it to be equivalent to the master_price
    def check_price
      return unless self.price.nil?
      if product && product.master_price
        self.price = product.master_price
      else
        errors.add_to_base("Must supply price for variant or master_price for product.")
        return false
      end
    end
end
