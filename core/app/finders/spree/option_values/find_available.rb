module Spree
  module OptionValues
    class FindAvailable
      def initialize(scope: OptionValue.spree_base_scopes, currency: nil, taxon: nil)
        @scope = scope
        @currency = currency
        @taxon = taxon
      end

      def execute
        filterable_options = scope.filterable
        filterable_options.for_products(products_scope)
      end

      private

      attr_reader :scope, :currency, :taxon

      def products_scope
        products = products_by_currency(Product.spree_base_scopes)
        products_by_taxon(products)
      end

      def products_by_currency(products)
        products.active(currency)
      end

      def products_by_taxon(products)
        return products if taxon.nil?

        products.in_taxon(taxon)
      end
    end
  end
end
