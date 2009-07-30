class TaxRate < ActiveRecord::Base
  belongs_to :zone
  belongs_to :tax_category
  
  validates_presence_of :amount
  validates_numericality_of :amount
  
  has_calculator
  named_scope :by_zone, lambda { |zone| { :conditions => ["zone_id = ?", zone] } }

  def calculate_tax(order)
    calculator.compute(order)
  end

end
