class Charge < Adjustment
  validates_presence_of :secondary_type

  def calculate_adjustment
    if adjustment_source
      case secondary_type
      when "TaxCharge"
        calculate_tax_charge
      when "ShippingCharge"
        calculate_shipping_charge
      else
        super
      end
    end
  end

  def calculate_tax_charge
    return unless order.shipment.address
    
    zones = Zone.match(order.shipment.address)
    tax_rates = zones.map{|zone| zone.tax_rates}.flatten.uniq
    calculated_taxes = tax_rates.map{|tax_rate| tax_rate.calculate_tax(order)}
    return(calculated_taxes.sum)
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

end