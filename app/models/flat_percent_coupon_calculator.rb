class FlatPercentCouponCalculator < Calculator
  preference :flat_percent, :decimal, :default => 0

  def calculate_discount(checkout)    
    checkout.order.item_total * self.preferred_flat_percent
  end  
end
