module Spree
  module Filters
    class PropertyPresenter
      def initialize(property:, product_properties:)
        @property = property
        @product_properties = product_properties
      end

      attr_reader :product_properties

      delegate_missing_to :property

      def uniq_values
        property.uniq_values(product_properties_scope: product_properties)
      end

      def to_h
        {
          id: property.id,
          name: property.name,
          presentation: property.presentation,
          values: values_hash
        }
      end

      private

      attr_reader :property

      def values_hash
        value_hashes = uniq_values.map do |filter_param, value|
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
