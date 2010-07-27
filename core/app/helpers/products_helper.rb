module ProductsHelper
  # returns the formatted change in price (from the master price) for the specified variant (or simply return
  # the variant price if no master price was supplied)
  def variant_price_diff(variant)
    return product_price(variant) unless variant.product.master.price
    diff = product_price(variant, :format_as_currency => false) - product_price(variant.product, :format_as_currency => false)
    return nil if diff == 0
    if diff > 0
      "(#{t("add")}: #{format_price diff.abs})"
    else
      "(#{t("subtract")}: #{format_price diff.abs})"
    end
  end

  # returns the price of the product to show for display purposes
  def product_price(product_or_variant, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text)
    options.reverse_merge! :format_as_currency => true, :show_vat_text => Spree::Config[:show_price_inc_vat]

    amount = product_or_variant.price
    amount += Calculator::Vat.calculate_tax_on(product_or_variant) if Spree::Config[:show_price_inc_vat]
    options.delete(:format_as_currency) ? format_price(amount, options) : amount
  end

  def format_price(price, options={})
    options.assert_valid_keys(:show_vat_text)
    options.reverse_merge! :show_vat_text => Spree::Config[:show_price_inc_vat]
    formatted_price = number_to_currency(price)
    if options[:show_vat_text]
      I18n.t(:price_with_vat_included, :price => formatted_price)
    else
      formatted_price
    end
  end

  # converts line breaks in product description into <p> tags (for html display purposes)
  def product_description(product)
    raw(product.description.gsub(/^(.*)$/, '<p>\1</p>'))
  end

  # generates nested url to product based on supplied taxon
  def seo_url(taxon, product = nil)
    return '/t/' + taxon.permalink if product.nil?
    warn "DEPRECATION: the /t/taxon-permalink/p/product-permalink urls are "+
      "not used anymore. Use product_url instead. (called from #{caller[0]})"
    return product_url(product)
  end

end
