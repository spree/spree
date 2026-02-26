module Spree
  module ProductsHelper
    include BaseHelper

    # returns the formatted price for the specified variant as a full price or a difference depending on configuration
    def variant_price(variant)
      Spree::Deprecation.warn('ProductsHelper#variant_price is deprecated and will be removed in Spree 5.5.')

      if Spree::Config[:show_variant_full_price]
        variant_full_price(variant)
      else
        variant_price_diff(variant)
      end
    end

    # returns the formatted price for the specified variant as a difference from product price
    def variant_price_diff(variant)
      Spree::Deprecation.warn('ProductsHelper#variant_price_diff is deprecated and will be removed in Spree 5.5.')

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
      Spree::Deprecation.warn('ProductsHelper#variant_full_price is deprecated and will be removed in Spree 5.5.')

      product = variant.product
      unless product.variants.active(current_currency).all? { |v| v.price == product.price }
        Spree::Money.new(variant.price, currency: current_currency).to_html
      end
    end

    def default_variant(variants, product)
      Spree::Deprecation.warn('ProductsHelper#default_variant is deprecated and will be removed in Spree 5.5.')

      variants_option_types_presenter(variants, product).default_variant || product.default_variant
    end

    def should_display_compare_at_price?(default_variant)
      Spree::Deprecation.warn('ProductsHelper#should_display_compare_at_price? is deprecated and will be removed in Spree 5.5.')

      default_variant_price = default_variant.price_in(current_currency)
      default_variant_price.compare_at_amount.present? && (default_variant_price.compare_at_amount > default_variant_price.amount)
    end

    def used_variants_options(variants, product)
      Spree::Deprecation.warn('ProductsHelper#used_variants_options is deprecated and will be removed in Spree 5.5.')

      variants_option_types_presenter(variants, product).options
    end

    def line_item_description_text(description_text)
      Spree::Deprecation.warn('ProductsHelper#line_item_description_text is deprecated and will be removed in Spree 5.5.')

      if description_text.present?
        truncate(strip_tags(description_text.gsub('&nbsp;', ' ').squish), length: 100)
      else
        Spree.t(:product_has_no_description)
      end
    end

    def cache_key_for_products(products = @products, additional_cache_key = nil)
      Spree::Deprecation.warn('ProductsHelper#cache_key_for_products is deprecated and will be removed in Spree 5.5.')

      max_updated_at = (products.except(:group, :order).maximum(:updated_at) || Date.today).to_formatted_s(:number)
      products_cache_keys = "spree/products/#{products.map(&:id).join('-')}-#{params[:page]}-#{params[:sort_by]}-#{max_updated_at}-#{@taxon&.id}"
      (common_product_cache_keys + [products_cache_keys] + [additional_cache_key]).compact.join('/')
    end

    def cache_key_for_product(product = @product)
      Spree::Deprecation.warn('ProductsHelper#cache_key_for_product is deprecated and will be removed in Spree 5.5.')

      cache_key_elements = common_product_cache_keys
      cache_key_elements += [
        product.cache_key_with_version,
        product.possible_promotions.map(&:cache_key)
      ]

      cache_key_elements.compact.join('/')
    end

    def limit_description(string)
      Spree::Deprecation.warn('ProductsHelper#limit_description is deprecated and will be removed in Spree 5.5.')

      return string if string.length <= 450

      string.slice(0..449) + '...'
    end

    def product_images(product, variants)
      Spree::Deprecation.warn('ProductsHelper#product_images is deprecated and will be removed in Spree 5.5.')

      if product.variants_and_option_values(current_currency).any?
        variants_without_master_images = variants.reject(&:is_master).map(&:images).flatten

        if variants_without_master_images.any?
          return variants_without_master_images
        end
      end

      variants.map(&:images).flatten
    end

    def product_variants_matrix(is_product_available_in_currency)
      Spree::Deprecation.warn('ProductsHelper#product_variants_matrix is deprecated and will be removed in Spree 5.5.')

      Spree::VariantPresenter.new(
        variants: @variants,
        is_product_available_in_currency: is_product_available_in_currency,
        current_currency: current_currency,
        current_price_options: current_price_options,
        current_store: current_store
      ).call.to_json
    end

    def product_relation_types
      Spree::Deprecation.warn('ProductsHelper#product_relation_types is deprecated and will be removed in Spree 5.5.')

      @product_relation_types ||= @product.respond_to?(:relation_types) ? @product.relation_types : []
    end

    def product_relations_by_type(relation_type)
      Spree::Deprecation.warn('ProductsHelper#product_relations_by_type is deprecated and will be removed in Spree 5.5.')

      return [] if product_relation_types.none? || !@product.respond_to?(:relations)

      product_ids = @product.relations.where(relation_type: relation_type).pluck(:related_to_id).uniq

      return [] if product_ids.empty?

      current_store.products.
        available.not_discontinued.distinct.
        where(id: product_ids).
        includes(
          :tax_category,
          master: [
            :prices,
            { images: { attachment_attachment: :blob } },
          ]
        ).
        limit(Spree::Config[:products_per_page])
    end

    def related_products
      Spree::Deprecation.warn('ProductsHelper#related_products is deprecated and will be removed in Spree 5.5. Please use ProductsHelper#relations from now on.')

      return [] unless @product.respond_to?(:has_related_products?)

      @related_products ||= relations_by_type('related_products')
    end

    def product_available_in_currency?
      Spree::Deprecation.warn('ProductsHelper#product_available_in_currency? is deprecated and will be removed in Spree 5.5.')

      !(@product_price.nil? || @product_price.zero?)
    end

    def common_product_cache_keys
      Spree::Deprecation.warn('ProductsHelper#common_product_cache_keys is deprecated and will be removed in Spree 5.5.')

      spree_base_cache_key + price_options_cache_key
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
