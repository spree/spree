class LineItem < ActiveRecord::Base
  before_validation :adjust_quantity
  belongs_to :order
  belongs_to :variant
  
  has_one :product, :through => :variant

  validates_presence_of :variant
  validates_numericality_of :quantity, :only_integer => true, :message => "must be an integer"
  validates_numericality_of :price

  attr_accessible :quantity
  
  def validate
    unless quantity && quantity >= 0
      errors.add(:quantity, "must be a non-negative value")
    end
    # avoid reload of order.inventory_units by using direct lookup
    unless Spree::Config[:allow_backorders]                               ||
           order   && InventoryUnit.order_id_equals(order).first.present? || 
           variant && quantity <= variant.on_hand                         
      errors.add(:quantity, " is too large-- stock on hand cannot cover requested quantity!")
    end
  end
  
  def increment_quantity
    self.quantity += 1
  end

  def decrement_quantity
    self.quantity -= 1
  end
  
  def total
    self.price * self.quantity  
  end
  alias amount total
  
  def adjust_quantity    
    self.quantity = 0 if self.quantity.nil? || self.quantity < 0
  end
end

