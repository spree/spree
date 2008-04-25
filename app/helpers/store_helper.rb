module StoreHelper
  
  # returns the price of the product to show for display purposes
  def product_price(product)
    return product.master_price if product.master_price
    return product.variant.price
  end
  
  # returns the formatted change in price (from the master price) for the specified variant
  def variant_price_diff(variant)
    diff = variant.price - variant.product.master_price
    return nil if diff == 0
    if diff > 0
      "(Add: #{number_to_currency diff.abs})"
    else
      "(Subtract: #{number_to_currency diff.abs})"
    end
  end
end