class FlatRate
  
  def description
    "Flat Rate Shipping (USPS)"
  end
  
  def shipping_cost(order)
    return FLAT_SHIPPING_RATE
  end
end