module Spree
  module OptionValues
    class FindAvailable
      def initialize(scope: OptionValue.spree_base_scopes, products_scope: Product.spree_base_scopes)
        @scope = scope
        @products_scope = products_scope
      end

      def execute
        filterable_options = scope.filterable
        filterable_options.for_products(products_scope)
      end

      private

      attr_reader :scope, :products_scope
    end
  end
end
