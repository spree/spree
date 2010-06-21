class TaxCharge < Charge
  def calculate_adjustment
    adjustment_source && calculate_tax_charge
  end

  # Calculates taxation amountbased on Calculator::Vat or Calculator::SalesTax
  def calculate_tax_charge
    return unless order.shipment
    return Calculator::Vat.calculate_tax(order) if order.shipment.address.blank? and Spree::Config[:show_price_inc_vat]
    return unless order.shipment.address
    zones = Zone.match(order.shipment.address)
    tax_rates = zones.map{|zone| zone.tax_rates}.flatten.uniq
    calculated_taxes = tax_rates.map{|tax_rate| tax_rate.calculate_tax(order)}
    return(calculated_taxes.sum)
  end

  # Checks if charge is applicable for the order.
  # if it's tax or shipping charge we always preserve it (even if it's 0)
  # otherwise we fall back to default adjustment behaviour.
  def applicable?
    true
  end
end