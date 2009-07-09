class FlatRateCouponCalculator < Calculator
  preference :flat_rate_amount, :decimal, :default => 0

  def calculate_discount(checkout)    
    self.preferred_flat_rate_amount
  end  
end
