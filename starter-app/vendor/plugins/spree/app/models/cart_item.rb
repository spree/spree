class CartItem < ActiveRecord::Base
  belongs_to :product
  belongs_to :variant
  belongs_to :cart
  
  validates_presence_of :product, :quantity
  validates_numericality_of :quantity, :only_integer => true
  
  def validate
    unless quantity && quantity >= 0
      errors.add(:quantity, "must be a positive value")
    end
  end
  
  def increment_quantity
    self.quantity += 1
  end

  def decrement_quantity
    self.quantity -= 1
  end
  
  def price
    self.product.price
  end
  
end
