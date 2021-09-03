module Spree
  module Products
    class PropertyFiltersPresenter
      def initialize(product_properties)
        @product_properties = product_properties
      end

      def to_a
        grouped_options.map { |property, product_properties| property_hash(property, product_properties) }
      end

      private

      attr_reader :product_properties

      def grouped_options
        product_properties.group_by(&:property)
      end

      def property_hash(property, product_properties)
        {
          id: property.id,
          name: property.name,
          presentation: property.presentation,
          values: values_hash(property, product_properties)
        }
      end

      def values_hash(property, product_properties)
        unique_values = property.uniq_values(product_properties_scope: product_properties)
        value_hashes = unique_values.map do |filter_param, value|
          {
            value: value,
            filter_param: filter_param
          }
        end
        value_hashes.sort_by { |e| e[:value] }
      end
    end
  end
end
