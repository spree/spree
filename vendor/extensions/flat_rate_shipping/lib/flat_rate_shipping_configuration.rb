class FlatRateShippingConfiguration < Configuration

  preference :flat_rate_amount, :decimal, :default => 12.99
  
  validates_presence_of :name
  validates_uniqueness_of :name
end
