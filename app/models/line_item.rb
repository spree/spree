class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :variant

  validates_presence_of :variant
  validates_numericality_of :quantity
  validates_numericality_of :price
  
  def self.from_cart_item(cart_item)
    line_item = self.new
    line_item.quantity = cart_item.quantity
    line_item.price = cart_item.price
    line_item.variant = cart_item.variant
    line_item
  end  
  
  def total
    self.price * self.quantity  
  end
  
end

