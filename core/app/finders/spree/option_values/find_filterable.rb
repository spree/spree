module Spree
  module OptionValues
    class FindFilterable
      def initialize(scope: OptionValue.spree_base_scopes, products_scope: Product.spree_base_scopes)
        @scope = scope
        @products_scope = products_scope
      end

      def execute
        scope.
          filterable.
          where(variants: { product_id: products_scope.pluck(:id) })
      end

      private

      attr_reader :scope, :products_scope
    end
  end
end
