module Spree
  module ProductsHelper
    # returns the formatted change in price (from the master price) for the specified variant (or simply return
    # the variant price if no master price was supplied)
    def variant_price_diff(variant)
      return product_price(variant) unless variant.product.master.price
      diff = product_price(variant, :format_as_currency => false) - product_price(variant.product, :format_as_currency => false)
      return nil if diff == 0
      if diff > 0
        "(#{t(:add)}: #{format_price diff.abs})"
      else
        "(#{t(:subtract)}: #{format_price diff.abs})"
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

    # converts line breaks in product description into <p> tags (for html display purposes)
    def product_description(product)
      raw(product.description.gsub(/^(.*)$/, '<p>\1</p>'))
    end

    def variant_images_hash(product)
      product.variant_images.inject({}) { |h, img| (h[img.viewable_id] ||= []) << img; h }
    end
  end
end
