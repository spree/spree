# applies the specified sales tax rate to all taxable items if the order is being shipped to a state 
# that requires sales tax
class SalesTax
  
  # rate map can be override by the setter (for testing purposes)
  @@rate_map = SALES_TAX_RATES
  
  # set this constant to be the id of the tax treatment used for sales tax in the db
  US_SALES_TAX = 2
  
  # right now this is just used in testing but its possible we may want to programatically set this value
  def self.rate_map= (rate_map)
    @@rate_map = rate_map    
  end
  
  def self.calc_tax(order)
    state = order.ship_address.state.abbr.to_sym
    return 0 unless @@rate_map.has_key? state
   
    tt = 0
    order.line_items.each do |li|
      tt += li.total if li.product.apply_tax_treatment? US_SALES_TAX
    end
    tt * @@rate_map[state]
  end
end