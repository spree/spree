module Spree
  module TaxCalculator
    def calculate_tax(order)
      # For now we're assuming every item in the order is either taxable or non-taxable (depending on the state.)
      # We'll replace with something more sophisticated later (plus you can always write your own extension.)
      state = order.ship_address.state
      tax_rate = TaxRate.find(:first,
                              :select => "tr.*", 
                              :conditions => {"st.name", state.name},
                              :joins => "as tr inner join states as st on tr.state_id = st.id")
      if tax_rate
        order.tax_amount = tax_rate.rate * order.item_total
      else
        order.tax_amount = 0 unless tax_rate
      end
    end
  end
end