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

        scope = apply_search_and_filters(scope, query: query, filters: filters)
        scope = scope.with_option_value_ids(Array(option_value_ids)) if option_value_ids.present?

        # Total count (before sorting to avoid computed column conflicts with count)
        total = scope.distinct.count

        # Sorting + pagination
        scope = apply_sort(scope, sort)
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
        option_value_ids = Array(filters.delete('with_option_value_ids') || filters.delete(:with_option_value_ids))

        # Apply text search + ransack filters (without option values)
        scope_before_options = apply_search_and_filters(scope, query: query, filters: filters)

        # Apply option value filters for the final scope
        scope_with_options = if option_value_ids.present?
                               scope_before_options.with_option_value_ids(option_value_ids)
                             else
                               scope_before_options
                             end

        filter_facets = build_facets(scope_with_options, category: category, option_value_ids: option_value_ids, scope_before_options: scope_before_options)

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

      def build_facets(scope, category: nil, option_value_ids: [], scope_before_options: nil)
        return { filters: [], sort_options: available_sort_options, default_sort: 'manual', total_count: scope.distinct.count } unless defined?(Spree::Api::V3::FiltersAggregator)

        Spree::Api::V3::FiltersAggregator.new(
          scope: scope,
          currency: currency,
          category: category,
          option_value_ids: option_value_ids,
          scope_before_options: scope_before_options || scope
        ).call
      end

      def sanitize_filters(filters)
        return {} if filters.blank?

        filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
        filters.except('search', :search, '_category', :_category, 'with_option_value_ids', :with_option_value_ids)
      end

      def apply_sort(scope, sort)
        return scope if sort.blank?

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

      def available_sort_options
        %w[price -price best_selling name -name -available_on available_on].map { |id| { id: id } }
      end
    end
  end
end
