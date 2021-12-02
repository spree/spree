module Spree
  module OptionValues
    class FindAvailable
      include ProductFilterable

      def initialize(scope: OptionValue.spree_base_scopes, products_scope: Product.spree_base_scopes)
        @scope = scope
        @products_scope = products_scope
      end

      def execute
        find_available(scope, products_scope).select(select_args).order(order_args)
      end

      private

      attr_reader :scope, :products_scope

      def select_args
        "#{OptionValue.table_name}.*, #{OptionType.table_name}.position AS option_type_position"
      end

      def order_args
        "option_type_position, #{OptionValue.table_name}.position"
      end
    end
  end
end
