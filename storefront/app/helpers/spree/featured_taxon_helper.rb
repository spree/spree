module Spree
  module FeaturedTaxonHelper
    def taxon_products(currency, featured_taxon)
      @products ||= begin
        finder_params = {
          store: featured_taxon.store,
          filter: { taxons: featured_taxon.preferred_taxon_id },
          currency: currency,
          sort_by: 'default'
        }

        products_finder = Spree::Dependencies.products_finder.constantize
        products_finder.new(scope: featured_taxon.store.products.includes(storefront_products_includes), params: finder_params).execute.limit(featured_taxon.preferred_max_products_to_show)
      end
    end
  end
end
