module Spree
  module FiltersHelper
    def products_for_filters_default_scope
      scope = storefront_products_scope
      scope = scope.in_taxon(@taxon) if @taxon.present?
      scope = scope.search_by_name(params[:q].strip).unscope(:order) if params[:q].present?
      scope
    end

    def products_for_filters_scope(except_filters: [])
      products_finder = Spree::Dependencies.products_finder.constantize

      finder_params = default_products_finder_params
      finder_params[:filter] = finder_params[:filter].except(*except_filters) if except_filters.any?

      products = products_finder.new(scope: storefront_products_scope, params: finder_params).execute
      current_store.products.where(id: products.unscope(:order).ids)
    end

    def storefront_products_for_filters
      @storefront_products_for_filters ||= products_for_filters_scope
    end

    def default_storefront_products_for_filters
      @default_storefront_products_for_filters ||= products_for_filters_default_scope.unscope(:order)
    end

    def product_filters_aggregations
      @product_filters_aggregations ||= Rails.cache.fetch(["product-filters-aggregations", storefront_products_for_filters.cache_key_with_version], expires_in: 1.day) do
        storefront_products_for_filters.
        joins(variants_including_master: :option_values).
        group("#{Spree::OptionValue.table_name}.id").
        distinct.
        count
      end
    end

    def product_single_filter_aggregations
      @product_single_filter_aggregations ||= Rails.cache.fetch(["product-single-filter-aggregations", default_storefront_products_for_filters.cache_key_with_version], expires_in: 1.day) do
        default_storefront_products_for_filters.
        joins(variants_including_master: :option_values).
        group("#{Spree::OptionValue.table_name}.id").
        distinct.
        count
      end
    end

    def products_count_for_filter(name, value_id)
      aggregations = single_option_filter_selected?(name) ? product_single_filter_aggregations : product_filters_aggregations
      aggregations.fetch(value_id, 0)
    end

    def filter_price_range
      @filter_price_range ||= begin
        products = products_for_filters_scope(except_filters: [:price])

        Rails.cache.fetch(["price-range", products.cache_key_with_version, current_currency], expires_in: 1.day) do
          {
            min: Spree::Price.for_products(products, current_currency).minimum(:amount) || 0.to_d,
            max: Spree::Price.for_products(products, current_currency).maximum(:amount) || 0.to_d
          }
        end
      end
    end

    def filter_stock_count
      @filter_stock_count ||= begin
        products = products_for_filters_scope(except_filters: [:purchasable, :out_of_stock])

        Rails.cache.fetch(["stock-count", products.cache_key_with_version], expires_in: 1.day) do
          {
            in_stock: products.in_stock.distinct.count,
            out_of_stock: products.out_of_stock.distinct.count
          }
        end
      end
    end

    def default_storefront_filter_values_scope
      @default_storefront_filter_values_scope ||= Spree::OptionValue.for_products(products_for_filters_default_scope).distinct
    end

    def storefront_filter_values_scope(filter_selected)
      if filter_selected
        default_storefront_filter_values_scope
      else
        all_option_values_scope
      end
    end

    def all_option_values_scope
      @all_option_values_scope ||= Spree::OptionValue.for_products(storefront_products_scope).distinct
    end

    def filter_values_for_filter(filter)
      selected = single_option_filter_selected?(filter.name)
      if filter.option_values.loaded?
        storefront_filter_values_ids = storefront_filter_values_scope(selected).ids

        filter.option_values.find_all { |option_value| storefront_filter_values_ids.include?(option_value.id) }
      else
        filter.option_values.where(id: storefront_filter_values_scope(selected))
      end
    end

    def storefront_products_for_taxon_filters
      @storefront_products_for_taxon_filters ||= products_for_filters_scope(except_filters: [:taxons, :taxonomy_ids])
    end

    def filter_taxon_ids
      @filter_taxon_ids ||= Rails.cache.fetch([spree_base_cache_key, storefront_products_for_taxon_filters, @taxon], expires_in: 1.day) do
        scope = storefront_products_for_taxon_filters.joins(:classifications)
        scope = scope.in_taxon(@taxon).unscope(:order) if @taxon.present?
        scope.distinct.pluck(:taxon_id)
      end
    end

    def filter_taxons_for_taxonomy(taxonomy)
      taxon_depth = @taxon.present? ? @taxon.depth + 1 : 1

      taxonomy.taxons.where(depth: taxon_depth).order(:lft).find_all do |taxon|
        (taxon.cached_self_and_descendants_ids & filter_taxon_ids).any?
      end
    end

    def product_taxon_aggregations
      @product_taxon_aggregations ||= Rails.cache.fetch([spree_base_cache_key, storefront_products_for_taxon_filters, current_store.taxons], expires_in: 1.day) do
        current_store.taxons.
          joins(:classifications).
          where("#{Spree::Classification.table_name}.product_id" => storefront_products_for_taxon_filters.ids).
                                      group(
                                        "#{Spree::Taxon.table_name}.id",
                                        "#{Spree::Classification.table_name}.product_id"
                                      ).
          unscope(:order).
          count("#{Spree::Classification.table_name}.product_id")
      end
    end

    def products_count_for_taxon(taxon)
      taxon_self_and_descendants_ids = taxon.cached_self_and_descendants_ids
      aggregations = product_taxon_aggregations.select { |key, _value| key[0].in?(taxon_self_and_descendants_ids) }

      # We want to count unique products across the taxon tree
      aggregations.uniq { |key, _value| key[1] }.sum(&:last)
    end

    def filter_form_fields
      return '' if products_filters_params.blank?

      map_filters_params_to_form_fields(products_filters_params)
    end

    def map_filters_params_to_form_fields(filters_params, prefix_key = nil)
      filters_params.to_h.map do |key, value|
        key = CGI.escapeHTML(key)
        key = [prefix_key, key].join('][') if prefix_key.present?

        if value.is_a?(Array)
          value.map do |v|
            v = CGI.escapeHTML(v)
            "<input type='hidden' name='filter[#{key}][]' value='#{v}' />"
          end.join
        elsif value.is_a?(Hash)
          map_filters_params_to_form_fields(value, key)
        else
          value = CGI.escapeHTML(value)
          "<input type='hidden' name='filter[#{key}]' value='#{value}' />"
        end
      end.join.html_safe
    end

    def single_option_filter_selected?(filter_name)
      options_filter = permitted_products_params.dig(:filter, :options) || {}

      !price_filtered? && !taxons_filtered? &&
        options_filter.keys.length == 1 && options_filter.key?(filter_name)
    end

    def price_filtered?
      min_price = permitted_products_params.dig(:filter, :min_price).presence
      max_price = permitted_products_params.dig(:filter, :max_price).presence

      (min_price.present? && min_price.to_d >= filter_price_range[:min]) ||
        (max_price.present? && max_price.to_d <= filter_price_range[:max])
    end

    def taxons_filtered?
      permitted_products_params.dig(:filter, :taxon_ids)&.any?
    end
  end
end
