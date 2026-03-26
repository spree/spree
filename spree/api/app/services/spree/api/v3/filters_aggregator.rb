module Spree
  module Api
    module V3
      class FiltersAggregator
        # @param scope [ActiveRecord::Relation] Base product scope (fully filtered, including option values)
        # @param currency [String] Currency for price range
        # @param category [Spree::Category, nil] Optional category for default_sort and category filtering context
        # @param option_value_ids [Array<String>] Currently selected option value prefixed IDs (for disjunctive facet counts)
        # @param scope_before_options [ActiveRecord::Relation] Scope before option value filters (for disjunctive counts)
        def initialize(scope:, currency:, category: nil, option_value_ids: [], scope_before_options: nil)
          @scope = scope
          @currency = currency
          @category = category
          @option_value_ids = option_value_ids
          @scope_before_options = scope_before_options || scope
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
            # Disjunctive: count against scope WITHOUT this option type's filter
            count_scope = disjunctive_scope_for(option_type)
            values = option_type.option_values.for_products(count_scope).distinct.order(:position)
            next if values.empty?

            count_ids = count_scope.reorder('').distinct.pluck(:id)

            {
              id: option_type.prefixed_id,
              type: 'option',
              name: option_type.name,
              label: option_type.label,
              options: values.map { |ov| option_value_data(count_ids, ov) }
            }
          end
        end

        def option_value_data(product_ids, option_value)
          count = Spree::Product
            .where(id: product_ids)
            .joins(:option_value_variants)
            .where(Spree::OptionValueVariant.table_name => { option_value_id: option_value.id })
            .distinct
            .count

          {
            id: option_value.prefixed_id,
            name: option_value.name,
            label: option_value.label,
            position: option_value.position,
            count: count
          }
        end

        # Returns the scope with all option type filters EXCEPT the given one applied.
        # This gives disjunctive counts: selecting Blue still shows Red's true count.
        def disjunctive_scope_for(option_type)
          return @scope_before_options if grouped_selected_options.empty?

          other_groups = grouped_selected_options.except(option_type.id)

          # If this type has selections but no other types do, use scope before any option filters
          return @scope_before_options if other_groups.empty?

          # Rebuild: start from scope before options, apply only other option types
          scope = @scope_before_options
          other_groups.each_value do |ov_ids|
            matching = Spree::Variant.where(deleted_at: nil)
                                     .joins(:option_value_variants)
                                     .where(Spree::OptionValueVariant.table_name => { option_value_id: ov_ids })
                                     .select(:product_id)
            scope = scope.where(id: matching)
          end
          scope
        end

        # Group selected option value IDs by option type (cached, single query)
        def grouped_selected_options
          @grouped_selected_options ||= begin
            return {} if @option_value_ids.blank?

            decoded = @option_value_ids.filter_map { |id| Spree::OptionValue.decode_prefixed_id(id) }
            return {} if decoded.empty?

            Spree::OptionValue.where(id: decoded).group_by(&:option_type_id).transform_values { |ovs| ovs.map(&:id) }
          end
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
