class FlatRateShippingCalculator < ShippingCalculator
  preference :flat_rate_amount, :decimal, :default => 0  
  
  def calculate_shipping(shipment)
    return self.preferred_flat_rate_amount
  end  
end