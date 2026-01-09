module Spree
  module ProductsHelper
    include BaseHelper

    def product_cache_key(product)
      [
        current_theme,
        current_store,
        try_spree_current_user,
        current_currency,
        I18n.locale,
        product.cache_key_with_version,
        product.available?,
        product.discontinued?,
      ]
    end

    def should_display_compare_at_price?(product_or_variant)
      price = product_or_variant.price_in(current_currency)
      price.compare_at_amount.present? && (price.compare_at_amount > price.amount)
    end

    def weeks_online(product)
      Spree::Deprecation.warn('weeks_online is deprecated and will be removed in Spree 5.2')

      (Time.current - product.activated_at.in_time_zone(current_store.preferred_timezone)).seconds.in_weeks.to_i.abs
    end

    def product_not_selected_options(product, selected_variant, options_param_name: :options)
      product.option_types.map do |option_type|
        if product_selected_option_for_option(
          option_type,
          product: product,
          selected_variant: selected_variant,
          options_param_name: options_param_name
        ).present?
          next
        else
          option_type
        end
      end.compact_blank
    end

    def product_selected_option_for_option(option_type, product:, selected_variant: nil, options_param_name: :options)
      @memoized_values ||= {}
      memoized_key = "#{product.id}-#{selected_variant&.id}-#{option_type.id}-#{options_param_name}"

      product_selected_options_hash = if params[options_param_name].present?
                                        params[options_param_name].split(',').to_h do |option|
                                          key, *value = option.split(':')
                                          [key, value.join(':')]
                                        end
                                      else
                                        {}
                                      end

      @memoized_values[memoized_key] ||=
        if selected_variant.present?
          selected_variant.option_values.find { |ov| ov.option_type_id == option_type.id }
        elsif product_selected_options_hash.present? && product_selected_options_hash[option_type.id.to_s].present? # user selected variant which is not available
          option_type.option_values.find { |v| v.name == product_selected_options_hash[option_type.id.to_s] }
        elsif option_type.color? && (available_variant = product.first_available_variant(current_currency))
          available_variant.option_values.find { |ov| ov.option_type_id == option_type.id }
        elsif option_type.color? && product.first_available_variant(current_currency).nil?
          product.variants.first&.option_values&.find { |ov| ov.option_type_id == option_type.id }
        end
    end

    def product_option_values_for_option(option_type, product:)
      product.option_values.includes(:option_type).
        find_all { |option_value| option_value.option_type_id == option_type.id }.
        uniq { |ov| [ov.name, ov.option_type&.name] }
    end

    def product_media_gallery_images(product, selected_variant:, variant_from_options:, options_param_name: :options)
      images = selected_variant&.images&.to_a || []
      images ||= variant_from_options&.images&.to_a if images.empty?

      if images.compact.empty?
        first_option_type = product.option_types.first

        if first_option_type.present?
          variant_for_first_option = product_variant_for_selected_option(
            first_option_type, product: product, selected_variant: selected_variant, options_param_name: options_param_name
          )

          images << variant_for_first_option.images.to_a if variant_for_first_option.present?
        end
      end

      images << product.master&.images&.to_a
      images << product.default_image if images.flatten.compact.empty?

      images.flatten.compact.uniq(&:id)
    end

    def variant_featured_image(variant)
      return nil unless variant

      variant.images.first
    end

    def image_alt(image)
      @memoized_image_alts ||= {}
      key = image.id

      @memoized_image_alts[key] ||=
        image.alt.presence ||
        (image.viewable.descriptive_name if image.viewable_type == 'Spree::Variant') ||
        @product.name
    end

    def product_variant_for_selected_option(option_type, product:, selected_variant:, options_param_name: :options)
      selected_value_for_option = product_selected_option_for_option(
        option_type,
        product: product,
        selected_variant: selected_variant,
        options_param_name: options_param_name
      )
      return unless selected_value_for_option.present?

      product.variants.with_option_value(option_type.name, selected_value_for_option.name).first
    end

    def products_selected_filters_count
      params[:filters].present? ? params[:filters].split(',').count : 0
    end

    def products_sort
      @products_sort ||= permitted_products_params[:sort_by]&.strip_html_tags.presence || default_products_sort
    end

    def taxons_sort_options
      @taxons_sort_options ||= [
        { name: Spree.t('products_sort_options.relevance'), value: 'manual' },
        { name: Spree.t('products_sort_options.best_selling'), value: 'best-selling' },
        { name: Spree.t('products_sort_options.name_a_z'), value: 'name-a-z' },
        { name: Spree.t('products_sort_options.name_z_a'), value: 'name-z-a' },
        { name: Spree.t('products_sort_options.price_low_to_high'), value: 'price-low-to-high' },
        { name: Spree.t('products_sort_options.price_high_to_low'), value: 'price-high-to-low' },
        { name: Spree.t('products_sort_options.newest_first'), value: 'newest-first' },
        { name: Spree.t('products_sort_options.oldest_first'), value: 'oldest-first' }
      ]
    end

    def product_breadcrumb_taxons(product)
      return Spree::Taxon.none if product.main_taxon.blank?

      # using find_all as we already iterate over the taxons in #product_json_ld_breadcrumbs
      product.main_taxon.self_and_ancestors.find_all { |taxon| taxon.depth != 0 }
    end

    # Generates the JSON-LD elements for a list of products.
    #
    # @param product_slugs [Array<String>] The slugs of the products to generate elements for
    # @return [Array<Hash>] The JSON-LD elements
    def product_list_json_ld_elements(product_slugs)
      product_slugs.each_with_index.map do |product_slug, index|
        {
          '@type' => 'ListItem',
          'position' => index + 1,
          'url' => spree.product_url(product_slug, host: current_store.url_or_custom_domain)
        }
      end
    end

    # Generates the JSON-LD breadcrumbs for a product.
    #
    # @param product [Spree::Product] The product to generate breadcrumbs for
    # @return [Hash] The JSON-LD breadcrumbs
    def product_json_ld_breadcrumbs(product)
      json_ld = {
        '@context' => 'https://schema.org',
        '@type' => 'BreadcrumbList',
        'itemListElement' => [
          {
            '@type': 'ListItem',
            'position' => 1,
            'name' => 'Homepage',
            'item' => spree.root_url(host: current_store.url_or_custom_domain)
          }
        ]
      }

      if product.main_taxon.present?
        product.main_taxon.self_and_ancestors.each_with_index do |taxon, index|
          json_ld['itemListElement'] << {
            '@type' => 'ListItem',
            'position' => index + 2,
            'name' => taxon.name,
            'item' => spree.nested_taxons_url(taxon, host: current_store.url_or_custom_domain)
          }
        end
      end

      json_ld['itemListElement'] << {
        '@type' => 'ListItem',
        'position' => json_ld['itemListElement'].length + 1,
        'name' => product.name
      }

      json_ld
    end

    def option_type_colors_preview_styles(option_type)
      return unless option_type.color?

      Spree::ColorsPreviewStylesPresenter.new(option_type.option_values.map { |ov| { name: ov.name, filter_name: ov.name } }).to_s
    end

    def product_properties(product)
      product.product_properties.joins(:property).merge(Spree::Property.available_on_front_end).sort_by_property_position
    end
  end
end
