class ShippingCharge < Charge
  def calculate_adjustment
    adjustment_source && calculate_shipping_charge
  end

  # Calculates shipping cost using calculators from shipping_rates and shipping_method
  # shipping_method calculator is used when there's no corresponding shipping_rate calculator
  #
  # shipping costs are calculated for each shipping_category - so if order have items
  # from 3 shipping categories, shipping cost will triple.
  # You can alter this behaviour by overwriting this method in your site extension
  def calculate_shipping_charge
    return unless shipping_method = adjustment_source.shipping_method
    shipping_method.calculate_cost(adjustment_source)
  end

  # Checks if charge is applicable for the order.
  # if it's tax or shipping charge we always preserve it (even if it's 0)
  # otherwise we fall back to default adjustment behaviour.
  def applicable?
    true
  end
end
