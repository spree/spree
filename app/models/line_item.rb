class LineItem < ActiveRecord::Base
  before_validation :adjust_quantity
  belongs_to :order
  belongs_to :variant

  validates_presence_of :variant
  validates_numericality_of :quantity, :only_integer => true, :message => "must be an integer"
  validates_numericality_of :price
  
  def validate
    unless quantity && quantity >= 0
      errors.add(:quantity, "must be a positive value")
    end
    unless quantity <= 100000
      errors.add(:quantity, "is too large")
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
  
  def adjust_quantity    
    self.quantity = 0 if self.quantity < 0
  end
end

