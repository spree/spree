module Spree
  module Api
    module V3
      class FiltersAggregator
        SORT_OPTION_IDS = %w[
          manual
          best-selling
          price-low-to-high
          price-high-to-low
          newest-first
          oldest-first
          name-a-z
          name-z-a
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
            sort_options: sort_options,
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

        def sort_options
          SORT_OPTION_IDS.map do |id|
            { id: id, label: Spree.t("products_sort_options.#{id.underscore}") }
          end
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
            label: Spree.t(:price),
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
            label: Spree.t(:availability),
            options: [
              { id: 'in_stock', label: Spree.t(:in_stock), count: in_stock_count },
              { id: 'out_of_stock', label: Spree.t(:out_of_stock), count: out_of_stock_count }
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
          # Count products in scope that have this option value
          # We use a subquery approach to avoid GROUP BY conflicts when scope includes joins (like in_taxon)
          # Join directly to option_value_variants for efficiency (skips joining through option_values table)
          count = Spree::Product
            .where(id: base_scope_product_ids)
            .joins(:option_value_variants)
            .where(Spree::OptionValueVariant.table_name => { option_value_id: option_value.id })
            .distinct
            .count

          {
            id: option_value.prefix_id,
            label: option_value.presentation,
            name: option_value.name,
            position: option_value.position,
            count: count
          }
        end

        def base_scope_product_ids
          @base_scope_product_ids ||= @scope.reorder('').distinct.pluck(:id)
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
            label: Spree.t(:category),
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
