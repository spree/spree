module OrdersHelper  
  def order_price(order, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
    options.reverse_merge! :format_as_currency => true, :show_vat_text => true
    
    # overwrite show_vat_text if show_price_inc_vat is false
    options[:show_vat_text] = Spree::Tax::Config[:show_price_inc_vat]

    amount =  order.item_total    
    amount += Spree::VatCalculator.calculate_tax(order) if Spree::Tax::Config[:show_price_inc_vat]    

    options.delete(:format_as_currency) ? format_price(amount, options) : amount
  end
end