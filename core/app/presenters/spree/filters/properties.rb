module Spree
  module Filters
    class Properties
      def initialize(product_properties_scope:)
        @product_properties = product_properties_scope.includes(:property)
      end

      def to_a
        grouped_options.map do |property, product_properties|
          Property.new(property: property, product_properties: product_properties)
        end
      end

      private

      attr_reader :product_properties

      def grouped_options
        product_properties.group_by(&:property)
      end
    end
  end
end
