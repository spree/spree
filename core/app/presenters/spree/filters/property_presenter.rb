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

      private

      attr_reader :property
    end
  end
end
