class TaxRate < ActiveRecord::Base
  belongs_to :zone
  belongs_to :tax_category
  
  validates :amount, :presence => true
  validates :amount, :numericality => true
  
  has_calculator
  scope :by_zone, lambda { |zone| where("zone_id = ?", zone)}

  def calculate_tax(order)
    calculator.compute(order)
  end

end
