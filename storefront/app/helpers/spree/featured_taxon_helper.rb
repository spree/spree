module Spree
  module FeaturedTaxonHelper
    def taxon_products(currency, featured_taxon)
      @products_cache ||= {}
      @products_cache[featured_taxon.id] ||= begin
        finder_params = {
          store: current_store,
          filter: { taxons: featured_taxon.preferred_taxon_id },
          currency: currency,
          sort_by: 'default'
        }

        products_finder = Spree::Dependencies.products_finder.constantize
        products_finder.new(scope: current_store.products.includes(storefront_products_includes), params: finder_params).execute.limit(featured_taxon.preferred_max_products_to_show)
      end
    end
  end
end
