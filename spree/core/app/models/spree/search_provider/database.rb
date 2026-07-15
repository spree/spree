module Spree
  module SearchProvider
    class Database < Base
      CUSTOM_SORT_SCOPES = {
        'price' => :ascend_by_price,
        '-price' => :descend_by_price,
        'best_selling' => :by_best_selling
      }.freeze

      def search_and_filter(scope:, query: nil, filters: {}, sort: nil, page: 1, limit: 25)
        filters = filters.is_a?(Hash) ? filters.dup : {}
        option_value_ids = filters.delete('with_option_value_ids') || filters.delete(:with_option_value_ids)
        # Which grouping a 'manual' (position) sort orders within. The in_category /
        # in_collection filter (applied just below) already JOINs and scopes that
        # grouping's position table, so we only need to know *which* grouping is
        # active
        grouping = manual_sort_grouping(filters)

        scope = apply_search_and_filters(scope, query: query, filters: filters)
        scope = scope.with_option_value_ids(Array(option_value_ids)) if option_value_ids.present?

        # Total count (before sorting to avoid computed column conflicts with count)
        total = scope.distinct.count

        # Sorting + pagination
        scope = apply_sort(scope, sort, grouping: grouping)
        page = [page.to_i, 1].max
        limit = limit.to_i.clamp(1, 100)
        products = scope.offset((page - 1) * limit).limit(limit)

        SearchResult.new(
          products: products,
          total_count: total,
          pagy: build_pagy(total, page, limit)
        )
      end

      def filters(scope:, query: nil, filters: {})
        filters = filters.is_a?(Hash) ? filters.dup : {}
        category = filters.delete('_category') || filters.delete(:_category)
        collection = filters.delete('_collection') || filters.delete(:_collection)
        option_value_ids = Array(filters.delete('with_option_value_ids') || filters.delete(:with_option_value_ids))

        # Apply text search + ransack filters (without option values)
        scope_before_options = apply_search_and_filters(scope, query: query, filters: filters)

        # Apply option value filters for the final scope
        scope_with_options = if option_value_ids.present?
                               scope_before_options.with_option_value_ids(option_value_ids)
                             else
                               scope_before_options
                             end

        filter_facets = build_facets(scope_with_options, category: category, sort_order: collection&.sort_order, option_value_ids: option_value_ids, scope_before_options: scope_before_options)

        FiltersResult.new(
          filters: filter_facets[:filters],
          sort_options: filter_facets[:sort_options],
          default_sort: filter_facets[:default_sort],
          total_count: filter_facets[:total_count]
        )
      end

      private

      def apply_search_and_filters(scope, query: nil, filters: {})
        scope = scope.search(query) if query.present?

        ransack_filters = sanitize_filters(filters)
        if ransack_filters.present?
          search = scope.ransack(ransack_filters)
          scope = search.result(distinct: true)
        end

        scope
      end

      def build_pagy(count, page, limit)
        Pagy::Offset.new(count: count, page: page, limit: limit)
      end

      def build_facets(scope, category: nil, sort_order: nil, option_value_ids: [], scope_before_options: nil)
        return { filters: [], sort_options: available_sort_options, default_sort: 'manual', total_count: scope.distinct.count } unless defined?(Spree::Api::V3::FiltersAggregator)

        Spree::Api::V3::FiltersAggregator.new(
          scope: scope,
          currency: currency,
          category: category,
          sort_order: sort_order,
          option_value_ids: option_value_ids,
          scope_before_options: scope_before_options || scope
        ).call
      end

      def sanitize_filters(filters)
        return {} if filters.blank?

        filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
        filters.except('search', :search, '_category', :_category, '_collection', :_collection, 'with_option_value_ids', :with_option_value_ids)
      end

      def apply_sort(scope, sort, grouping: nil)
        # A category/collection page defaults to the merchant's manual (position)
        # order when `sort` is omitted — matching the `default_sort: 'manual'` the
        # filters endpoint advertises.
        sort = 'manual' if sort.blank? && grouping.present?
        return scope if sort.blank?

        return manual_sort(scope, grouping) if sort == 'manual'

        scope_method = CUSTOM_SORT_SCOPES[sort]
        if scope_method
          scope.reorder(nil).send(scope_method)
        else
          # Standard Ransack sort: 'name' → 'name asc', '-name' → 'name desc'
          ransack_sort = sort.split(',').map { |field|
            if field.start_with?('-')
              "#{field[1..]} desc"
            else
              "#{field} asc"
            end
          }.join(',')

          scope.ransack(s: ransack_sort).result
        end
      end

      # Which grouping a 'manual' sort orders within, inferred from the filter that
      # was applied (and therefore joined its position table). Only single-grouping
      # PLPs sort manually — in_categories (plural) has no single position axis.
      def manual_sort_grouping(filters)
        return :collection if filters.key?('in_collection') || filters.key?(:in_collection)
        return :category if filters.key?('in_category') || filters.key?(:in_category)

        nil
      end

      # 'manual' sort = the merchant's hand-set position within the grouping. The
      # in_category / in_collection filter already joined and scoped the position
      # table, so we just order by it — no re-resolution, no extra query. With no
      # grouping, 'manual' falls back to the unsorted scope (nothing to order by).
      def manual_sort(scope, grouping)
        case grouping
        when :collection
          # Flat: one product_collections row per product, so order by its position.
          # The filtered scope is DISTINCT and PostgreSQL requires ORDER BY columns
          # in the SELECT list, so select the position too.
          position = "#{Spree::ProductCollection.table_name}.position"
          scope.reorder(nil).
            select("#{Spree::Product.table_name}.*", position).
            order(Arel.sql("#{position} ASC"))
        when :category
          # Hierarchical: a product under a category AND its descendants has several
          # product_categories rows (in_category joins the whole subtree), so collapse
          # to MIN(position) grouped by product.
          position = "MIN(#{Spree::ProductCategory.table_name}.position)"
          scope.reorder(nil).
            select("#{Spree::Product.table_name}.*", "#{position} AS manual_position").
            group("#{Spree::Product.table_name}.id").
            order(Arel.sql("#{position} ASC"))
        else
          scope
        end
      end

      def available_sort_options
        %w[price -price best_selling name -name -available_on available_on].map { |id| { id: id } }
      end
    end
  end
end
