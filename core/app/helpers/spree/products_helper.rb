module Spree
  module ProductsHelper
    # returns the formatted price for the specified variant as a full price or a difference depending on configuration
    def variant_price(variant)
      if Spree::Config[:show_variant_full_price]
        variant_full_price(variant)
      else
        variant_price_diff(variant)
      end
    end


    # returns the formatted price for the specified variant as a difference from product price
    def variant_price_diff(variant)
      diff = variant.price - variant.product.price
      return nil if diff == 0
      if diff > 0
        "(#{t(:add)}: #{Spree::Money.new(diff.abs, { :currency => variant.currency })})"
      else
        "(#{t(:subtract)}: #{Spree::Money.new(diff.abs, { :currency => variant.currency })})"
      end
    end

    # returns the formatted full price for the variant, if at least one variant price differs from product price
    def variant_full_price(variant)
      product = variant.product
      unless product.variants.active.all? { |v| v.price == product.price }
        Spree::Money.new(variant.price, { :currency => variant.currency }).to_s
      end
    end

    # converts line breaks in product description into <p> tags (for html display purposes)
    def product_description(product)
      raw(product.description.gsub(/(.*?)\r?\n\r?\n/m, '<p>\1</p>'))
    end

    def line_item_description(variant)
      description = variant.product.description
      if description.present?
        truncate(strip_tags(description.gsub('&nbsp;', ' ')), :length => 100)
      else
        t(:product_has_no_description)
      end
    end

    def get_taxonomies
      @taxonomies ||= Spree::Taxonomy.includes(:root => :children)
    end
  end
end
