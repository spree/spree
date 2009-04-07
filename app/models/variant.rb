class Variant < ActiveRecord::Base
  after_update :adjust_inventory
  
  belongs_to :product
  has_many :inventory_units
  has_and_belongs_to_many :option_values
  
  validates_presence_of :product
  validate :check_price
  
  
  # default variant scope only lists non-deleted variants
  named_scope :active, :conditions => "deleted_at is null"
  named_scope :deleted, :conditions => "not deleted_at is null"
 
  # default extra fields for shipping purposes 
  @fields = [ {:name => 'Weight', :only => [:variant], :format => "%.2f"},
              {:name => 'Height', :only => [:variant], :format => "%.2f"},
              {:name => 'Width',  :only => [:variant], :format => "%.2f"},
              {:name => 'Depth',  :only => [:variant], :format => "%.2f"} ]
  
  def on_hand
    inventory_units.with_state("on_hand").size
  end

  def on_hand=(new_level)
    @new_level = new_level
  end
  
  def on_backorder
    inventory_units.with_state("backordered").size
  end
  
  def in_stock
    on_hand > 0
  end
  
  def self.additional_fields
    @fields
  end
  
  def self.additional_fields=(new_fields)
    @fields = new_fields
  end
  
  #Tries to get missing attribute value from  product
  def method_missing(method, *args)
    if product
      product.has_attribute?(method) ? product[method] : super
    else
      super
    end
  end
  
  def orderable?
    self.in_stock || ( !self.in_stock && self.allow_backordering) || Spree::Config[:allow_backorders]
  end

  private

    def adjust_inventory    
      return unless @new_level && @new_level.is_integer?    
      @new_level = @new_level.to_i
      # don't allow negative on_hand inventory
      return if @new_level < 0
      
      # fill backordered orders first
      inventory_units.with_state("backordered").each{|iu|
        if @new_level > 0
          iu.fill_backorder
          @new_level = @new_level - 1
        end
        break if @new_level < 1
        }
      
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
