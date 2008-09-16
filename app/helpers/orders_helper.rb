module OrdersHelper  
  def order_price(order, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
    options.reverse_merge! :show_price_inc_vat => Rails.cache.fetch('show_prices_inc_vat') {Spree::Config[:show_prices_inc_vat]}, :format_as_currency => true, :show_vat_text => true
    
    show_price_inc_vat = options.delete(:show_price_inc_vat)
    
    # overwrite show_vat_text if show_price_inc_vat is false
    options[:show_vat_text] = false unless show_price_inc_vat
    
    amount =  order.item_total
    amount += Spree::VatCalculator.calculate_tax(order, Rails.cache.read('vat_rates')) if show_price_inc_vat

    options.delete(:format_as_currency) ? format_price(amount, options) : amount
  end
end