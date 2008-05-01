module StoreHelper
  
  # returns the price of the product to show for display purposes
  def product_price(product)
    return nil if product.master_price.nil? and product.variants?
    return number_to_currency(product.master_price) if product.master_price
    product.variant ? number_to_currency(product.variant.price) : number_to_currency(0)
  end
  
  # returns the formatted change in price (from the master price) for the specified variant (or simply return 
  # the variant price if no master price was supplied)
  def variant_price_diff(variant)
    return number_to_currency(variant.price) unless variant.product.master_price
    diff = variant.price - variant.product.master_price
    return nil if diff == 0
    if diff > 0
      "(Add: #{number_to_currency diff.abs})"
    else
      "(Subtract: #{number_to_currency diff.abs})"
    end
  end
end