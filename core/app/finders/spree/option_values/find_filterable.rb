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
          where(variants: { product_id: products_ids })
      end

      private

      attr_reader :scope, :products_scope

      def products_ids
        products_scope.map(&:id)
      end
    end
  end
end
