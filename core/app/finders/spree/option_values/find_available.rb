module Spree
  module OptionValues
    class FindAvailable
      def initialize(scope: OptionValue.spree_base_scopes, currency: nil, taxon: nil)
        @scope = scope
        @currency = currency
        @taxon = taxon
      end

      def execute
        filterable_finder.execute
      end

      private

      attr_reader :scope, :currency, :taxon

      def filterable_finder
        FindFilterable.new(scope: scope, products_scope: products_scope)
      end

      def products_scope
        products = by_currency(Product.spree_base_scopes)
        by_taxon(products)
      end

      def by_currency(products)
        products.active(currency)
      end

      def by_taxon(products)
        return products if taxon.nil?

        products.in_taxon(taxon)
      end
    end
  end
end
