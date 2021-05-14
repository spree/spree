module Spree
  module Filters
    class Property
      def initialize(property:, product_properties:)
        @property = property
        @product_properties = product_properties
      end

      delegate_missing_to :property

      def uniq_values
        property.uniq_values(product_properties_scope: product_properties)
      end

      private

      attr_reader :property, :product_properties
    end
  end
end
