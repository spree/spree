module Spree
  module ProductsHelper
    # returns the formatted change in price (from the master price) for the specified variant (or simply return
    # the variant price if no master price was supplied)
    def variant_price_diff(variant)
      diff = variant.price - variant.product.price
      return nil if diff == 0
      if diff > 0
        "(#{t(:add)}: #{number_to_currency diff.abs})"
      else
        "(#{t(:subtract)}: #{number_to_currency diff.abs})"
      end
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
