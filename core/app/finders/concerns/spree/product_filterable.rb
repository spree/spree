module Spree
  module ProductFilterable
    private

    def find_available(scope, products_scope)
      scope.filterable.order("#{OptionType.table_name}.position, #{OptionValue.table_name}.position").for_products(products_scope)
    end
  end
end
