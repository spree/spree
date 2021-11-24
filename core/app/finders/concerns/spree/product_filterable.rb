module Spree
  module ProductFilterable
    private

    def find_available(scope, products_scope)
      scope.filterable.for_products(products_scope)
    end
  end
end
