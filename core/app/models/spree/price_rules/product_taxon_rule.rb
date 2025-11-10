module Spree
  module PriceRules
    class ProductTaxonRule < Spree::PriceRule
      preference :taxon_ids, :array, default: []
      preference :include_descendants, :boolean, default: true

      def applicable?(context)
        return true if preferred_taxon_ids.empty?

        product = context.variant.product
        product_taxon_ids = product.taxons.pluck(:id)

        if preferred_include_descendants
          taxon_ids_with_descendants = Spree::Taxon.where(id: preferred_taxon_ids)
                                                     .map { |t| [t.id] + t.descendants.pluck(:id) }
                                                     .flatten
          (product_taxon_ids & taxon_ids_with_descendants).any?
        else
          (product_taxon_ids & preferred_taxon_ids).any?
        end
      end

      def self.description
        'Apply pricing based on product taxon'
      end
    end
  end
end
