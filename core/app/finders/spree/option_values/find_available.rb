module Spree
  module OptionValues
    class FindAvailable
      include ProductFilterable

      def initialize(scope: OptionValue.spree_base_scopes.order(position: :asc), products_scope: Product.spree_base_scopes)
        @scope = scope
        @products_scope = products_scope
      end

      def execute
        find_available(scope, products_scope)
      end

      private

      attr_reader :scope, :products_scope
    end
  end
end
