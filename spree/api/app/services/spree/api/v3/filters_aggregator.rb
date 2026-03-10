module Spree
  module Api
    module V3
      class FiltersAggregator
        # @param scope [ActiveRecord::Relation] Base product scope (already filtered by store, availability, category, etc.)
        # @param currency [String] Currency for price range
        # @param category [Spree::Category, nil] Optional category for default_sort and category filtering context
        def initialize(scope:, currency:, category: nil)
          @scope = scope
          @currency = currency
          @category = category
        end

        def call
          {
            filters: build_filters,
            sort_options: sort_options,
            default_sort: to_api_sort(@category&.sort_order || 'manual'),
            total_count: @scope.distinct.count
          }
        end

        private

        def build_filters
          [
            price_filter,
            availability_filter,
            *option_type_filters,
            category_filter
          ].compact
        end

        def sort_options
          Spree::Taxon::SORT_ORDERS.map { |id| { id: to_api_sort(id) } }
        end

        # Converts internal sort format ('price asc') to API format ('price', '-price')
        def to_api_sort(sort_value)
          return sort_value unless sort_value.include?(' ')

          field, direction = sort_value.split(' ', 2)
          direction == 'desc' ? "-#{field}" : field
        end


        def price_filter
          # Remove ordering to avoid PostgreSQL DISTINCT + ORDER BY conflicts
          prices = Spree::Price.for_products(@scope.reorder(''), @currency)
          min = prices.minimum(:amount)
          max = prices.maximum(:amount)
          return nil if min.nil? || max.nil?

          {
            id: 'price',
            type: 'price_range',
            min: min.to_f,
            max: max.to_f,
            currency: @currency
          }
        end

        def availability_filter
          in_stock_count = @scope.in_stock.distinct.count
          out_of_stock_count = @scope.out_of_stock.distinct.count

          return nil if in_stock_count.zero? && out_of_stock_count.zero?

          {
            id: 'availability',
            type: 'availability',
            options: [
              { id: 'in_stock', count: in_stock_count },
              { id: 'out_of_stock', count: out_of_stock_count }
            ]
          }
        end

        def option_type_filters
          Spree::OptionType.filterable.includes(:option_values).order(:position).filter_map do |option_type|
            values = option_type.option_values.for_products(@scope).distinct.order(:position)
            next if values.empty?

            {
              id: option_type.prefixed_id,
              type: 'option',
              name: option_type.name,
              presentation: option_type.presentation,
              options: values.map { |ov| option_value_data(option_type, ov) }
            }
          end
        end

        def option_value_data(option_type, option_value)
          # Count products in scope that have this option value
          # We use a subquery approach to avoid GROUP BY conflicts when scope includes joins (like in_category)
          # Join directly to option_value_variants for efficiency (skips joining through option_values table)
          count = Spree::Product
            .where(id: base_scope_product_ids)
            .joins(:option_value_variants)
            .where(Spree::OptionValueVariant.table_name => { option_value_id: option_value.id })
            .distinct
            .count

          {
            id: option_value.prefixed_id,
            name: option_value.name,
            presentation: option_value.presentation,
            position: option_value.position,
            count: count
          }
        end

        def base_scope_product_ids
          @base_scope_product_ids ||= @scope.reorder('').distinct.pluck(:id)
        end

        def category_filter
          return nil if @category.nil?

          # Get child categories at the next depth level
          child_categories = @category.children.order(:lft).select do |child|
            # Only include categories that have products in the current scope
            @scope.in_category(child).exists?
          end

          return nil if child_categories.empty?

          {
            id: 'categories',
            type: 'category',
            options: child_categories.map { |c| category_option_data(c) }
          }
        end

        def category_option_data(category)
          count = @scope.in_category(category).distinct.count

          {
            id: category.prefixed_id,
            name: category.name,
            permalink: category.permalink,
            count: count
          }
        end
      end
    end
  end
end
