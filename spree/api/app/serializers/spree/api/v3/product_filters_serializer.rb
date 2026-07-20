module Spree
  module Api
    module V3
      class ProductFiltersSerializer < BaseSerializer
        typelize default_sort: :string,
                 total_count: :number,
                 filters: 'Array<ProductFilterPriceRange | ProductFilterAvailability | ProductFilterOption | ProductFilterCategory>',
                 sort_options: [:ProductFilterSortOption, { multi: true }]

        attributes :default_sort, :total_count

        attribute :filters do |result|
          result.filters.filter_map do |filter|
            filter_type = filter[:type]
            serializer_class = case filter_type
                               when 'price_range'
                                 Spree.api.product_filter_price_range_serializer
                               when 'availability'
                                 Spree.api.product_filter_availability_serializer
                               when 'option'
                                 Spree.api.product_filter_option_serializer
                               when 'category'
                                 Spree.api.product_filter_category_serializer
                               else
                                 raise ArgumentError, "Unknown filter type: #{filter_type.inspect}"
                               end

            serializer_class.new(filter, params: params).serializable_hash
          end
        end

        many :sort_options, resource: proc { Spree.api.product_filter_sort_option_serializer }
      end
    end
  end
end
