module Spree
  module TaxonsHelper
    # @param taxon [Spree::Taxon]
    # @param size [Integer]
    # @return [ActiveRecord::Relation<Spree::Product>] limited set of products for the taxon
    def taxon_products(taxon, size)
      @products_cache ||= {}
      @products_cache[taxon.id] ||= begin
        finder_params = {
          store: current_store,
          filter: { taxons: taxon.id },
          currency: current_currency,
          sort_by: 'default'
        }

        products_finder = Spree::Dependencies.products_finder.constantize
        products_finder.new(scope: current_store.products.includes(storefront_products_includes), params: finder_params).execute.limit(size).to_a
      end
    end
  end
end
