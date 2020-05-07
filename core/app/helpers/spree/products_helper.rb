module Spree
  module ProductsHelper
    include BaseHelper

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
      variant_amount = variant.amount_in(current_currency)
      product_amount = variant.product.amount_in(current_currency)
      return if variant_amount == product_amount || product_amount.nil?

      diff   = variant.amount_in(current_currency) - product_amount
      amount = Spree::Money.new(diff.abs, currency: current_currency).to_html
      label  = diff > 0 ? :add : :subtract
      "(#{Spree.t(label)}: #{amount})".html_safe
    end

    # returns the formatted full price for the variant, if at least one variant price differs from product price
    def variant_full_price(variant)
      product = variant.product
      unless product.variants.active(current_currency).all? { |v| v.price == product.price }
        Spree::Money.new(variant.price, currency: current_currency).to_html
      end
    end

    def default_variant(variants, product)
      variants_option_types_presenter(variants, product).default_variant || product.default_variant
    end

    def used_variants_options(variants, product)
      variants_option_types_presenter(variants, product).options
    end

    # converts line breaks in product description into <p> tags (for html display purposes)
    def product_description(product)
      description = if Spree::Config[:show_raw_product_description]
                      product.description
                    else
                      product.description.to_s.gsub(/(.*?)\r?\n\r?\n/m, '<p>\1</p>')
                    end
      description.blank? ? Spree.t(:product_has_no_description) : description
    end

    def line_item_description_text(description_text)
      if description_text.present?
        truncate(strip_tags(description_text.gsub('&nbsp;', ' ').squish), length: 100)
      else
        Spree.t(:product_has_no_description)
      end
    end

    def cache_key_for_products(products = @products, additional_cache_key = nil)
      max_updated_at = (products.maximum(:updated_at) || Date.today).to_s(:number)
      products_cache_keys = "spree/products/#{products.map(&:id).join('-')}-#{params[:page]}-#{params[:sort_by]}-#{max_updated_at}-#{@taxon&.id}"
      (common_product_cache_keys + [products_cache_keys] + [additional_cache_key]).compact.join('/')
    end

    def cache_key_for_product(product = @product)
      cache_key_elements = common_product_cache_keys
      cache_key_elements += [
        product.cache_key_with_version,
        product.possible_promotions.map(&:cache_key)
      ]

      cache_key_elements.compact.join('/')
    end

    def limit_descritpion(string)
      return string if string.length <= 450

      string.slice(0..449) + '...'
    end

    # will return a human readable string
    def available_status(product)
      return Spree.t(:discontinued) if product.discontinued?
      return Spree.t(:deleted) if product.deleted?

      if product.available?
        Spree.t(:available)
      elsif product.available_on&.future?
        Spree.t(:pending_sale)
      else
        Spree.t(:no_available_date_set)
      end
    end

    def product_images(product, variants)
      if product.variants_and_option_values(current_currency).any?
        variants_without_master_images = variants.reject(&:is_master).map(&:images).flatten

        if variants_without_master_images.any?
          return variants_without_master_images
        end
      end

      variants.map(&:images).flatten
    end

    def product_variants_matrix(is_product_available_in_currency)
      Spree::VariantPresenter.new(
        variants: @variants,
        is_product_available_in_currency: is_product_available_in_currency,
        current_currency: current_currency,
        current_price_options: current_price_options
      ).call.to_json
    end

    def related_products
      return [] unless @product.respond_to?(:has_related_products?) && @product.has_related_products?(:related_products)

      @related_products ||= @product.
                            related_products.
                            includes(
                              :tax_category,
                              master: [
                                :prices,
                                images: { attachment_attachment: :blob },
                              ]
                            ).
                            limit(Spree::Config[:products_per_page])
    end

    def product_available_in_currency?
      !(@product_price.nil? || @product_price.zero?)
    end

    def common_product_cache_keys
      base_cache_key + price_options_cache_key
    end

    private

    def price_options_cache_key
      current_price_options.sort.map(&:last).map do |value|
        value.try(:cache_key) || value
      end
    end

    def variants_option_types_presenter(variants, product)
      @variants_option_types_presenter ||= begin
        option_types = Spree::Variants::OptionTypesFinder.new(variant_ids: variants.map(&:id)).execute

        Spree::Variants::OptionTypesPresenter.new(option_types, variants, product)
      end
    end
  end
end
