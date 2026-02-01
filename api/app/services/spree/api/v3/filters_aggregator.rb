module Spree
  module Api
    module V3
      class FiltersAggregator
        SORT_OPTIONS = [
          { id: 'manual', label: 'Default' },
          { id: 'best-selling', label: 'Best Selling' },
          { id: 'price-low-to-high', label: 'Price: Low to High' },
          { id: 'price-high-to-low', label: 'Price: High to Low' },
          { id: 'newest-first', label: 'Newest First' },
          { id: 'oldest-first', label: 'Oldest First' },
          { id: 'name-a-z', label: 'Name: A-Z' },
          { id: 'name-z-a', label: 'Name: Z-A' }
        ].freeze

        # @param scope [ActiveRecord::Relation] Base product scope (already filtered by store, availability, taxon, etc.)
        # @param currency [String] Currency for price range
        # @param taxon [Spree::Taxon, nil] Optional taxon for default_sort and taxon filtering context
        def initialize(scope:, currency:, taxon: nil)
          @scope = scope
          @currency = currency
          @taxon = taxon
        end

        def call
          {
            filters: build_filters,
            sort_options: SORT_OPTIONS,
            default_sort: @taxon&.sort_order || 'manual',
            total_count: @scope.distinct.count
          }
        end

        private

        def build_filters
          [
            price_filter,
            availability_filter,
            *option_type_filters,
            taxon_filter
          ].compact
        end

        def price_filter
          prices = Spree::Price.for_products(@scope, @currency)
          min = prices.minimum(:amount)
          max = prices.maximum(:amount)
          return nil if min.nil? || max.nil?

          {
            id: 'price',
            type: 'price_range',
            label: 'Price',
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
            label: 'Availability',
            options: [
              { id: 'in_stock', label: 'In Stock', count: in_stock_count },
              { id: 'out_of_stock', label: 'Out of Stock', count: out_of_stock_count }
            ]
          }
        end

        def option_type_filters
          Spree::OptionType.filterable.includes(:option_values).order(:position).filter_map do |option_type|
            values = option_type.option_values.for_products(@scope).distinct.order(:position)
            next if values.empty?

            {
              id: option_type.prefix_id,
              type: 'option',
              label: option_type.presentation,
              name: option_type.name,
              options: values.map { |ov| option_value_data(option_type, ov) }
            }
          end
        end

        def option_value_data(option_type, option_value)
          # with_option_value uses group, so we need to count the keys or use a different approach
          count = @scope.with_option_value(option_type.name, option_value.name).length

          {
            id: option_value.prefix_id,
            label: option_value.presentation,
            name: option_value.name,
            position: option_value.position,
            count: count
          }
        end

        def taxon_filter
          return nil if @taxon.nil?

          # Get child taxons at the next depth level
          child_taxons = @taxon.children.order(:lft).select do |child|
            # Only include taxons that have products in the current scope
            @scope.in_taxon(child).exists?
          end

          return nil if child_taxons.empty?

          {
            id: 'taxons',
            type: 'taxon',
            label: 'Category',
            options: child_taxons.map { |t| taxon_option_data(t) }
          }
        end

        def taxon_option_data(taxon)
          count = @scope.in_taxon(taxon).distinct.count

          {
            id: taxon.prefix_id,
            label: taxon.name,
            permalink: taxon.permalink,
            count: count
          }
        end
      end
    end
  end
end
