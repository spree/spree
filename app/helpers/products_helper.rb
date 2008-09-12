module ProductsHelper
  # returns the price of the product to show for display purposes
  def product_price(product_or_variant, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
    options.reverse_merge! :show_price_inc_vat => Rails.cache.fetch('show_prices_inc_vat') {Spree::Config[:show_prices_inc_vat]}, :format_as_currency => true, :show_vat_text => true
    
    show_price_inc_vat = options.delete(:show_price_inc_vat)
    
    # overwrite show_vat_text if show_price_inc_vat is false
    options[:show_vat_text] = false unless show_price_inc_vat
    
    amount = product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price
    amount += Spree::VatCalculator.calculate_tax_on(product_or_variant) if show_price_inc_vat

    options[:format_as_currency] ? format_price(amount, options) : amount
  end
  
  # returns the formatted change in price (from the master price) for the specified variant (or simply return 
  # the variant price if no master price was supplied)
  def variant_price_diff(variant)
    return product_price(variant) unless variant.product.master_price
    diff = product_price(variant, :format_as_currency => false) - product_price(variant.product, :format_as_currency => false)
    return nil if diff == 0
    if diff > 0
      "(Add: #{format_price diff.abs})"
    else
      "(Subtract: #{format_price diff.abs})"
    end
  end
  
  def format_price(price, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text)
    options.reverse_merge! :format_as_currency => true, :show_vat_text => true
    
    output = options[:format_as_currency] ? number_to_currency(price) : price
    options[:show_vat_text]  ?  output.to_s + ' (inc. VAT)' : output
  end
  
  # converts line breaks in product description into <p> tags (for html display purposes)
  def product_description(product)
    product.description.gsub(/^(.*)$/, '<p>\1</p>')
  end  
end
