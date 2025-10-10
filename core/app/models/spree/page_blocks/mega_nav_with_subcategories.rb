module Spree
  module PageBlocks
    class MegaNavWithSubcategories < Spree::PageBlock
      preference :taxon_id, :string, default: ''
      preference :featured_taxon_id, :string, default: ''

      before_validation :make_taxon_id_valid

      def taxon
        store.taxons.find_by(id: preferred_taxon_id) if preferred_taxon_id.present?
      end

      def featured_taxon
        store.taxons.find_by(id: preferred_featured_taxon_id) if preferred_featured_taxon_id.present?
      end

      def icon_name
        'category'
      end

      def display_name
        taxon&.name || Spree.t(:mega_nav_with_subcategories)
      end

      private

      def make_taxon_id_valid
        self.preferred_taxon_id = preferred_taxon_id.presence || store.taxons.where(depth: 1).first&.id
      end
    end
  end
end
