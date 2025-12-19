module Spree
  module PageBuilder
    module Products
      module TouchTaxonsJobDecorator
        def perform(taxon_ids, taxonomy_ids)
          super(taxon_ids, taxonomy_ids)

          Spree::Taxons::TouchFeaturedSections.call(taxon_ids: taxon_ids)
        end
      end
    end
  end
end

Spree::Products::TouchTaxonsJob.prepend(Spree::PageBuilder::Products::TouchTaxonsJobDecorator)
