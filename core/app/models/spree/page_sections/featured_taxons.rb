module Spree
  module PageSections
    class FeaturedTaxons < Spree::PageSection
      before_validation :make_heading_size_valid
      before_validation :make_alignment_valid

      preference :heading, :string, default: Spree.t('page_sections.featured_taxons.heading_default')
      preference :heading_size, :string, default: 'large'
      preference :heading_alignment, :string, default: 'left'

      def icon_name
        'layout-grid'
      end

      def links_available?
        true
      end

      def allowed_linkable_types
        [
          [Spree.t(:taxon), 'Spree::Taxon']
        ]
      end

      def default_linkable_type
        default_linkable_resource.class.to_s
      end

      def default_linkable_resource
        @default_linkable_resource ||= Spree::Taxon.where(parent: store.taxonomies.first.root).first ||
                                        store.theme_pages.find_by(type: 'Spree::Pages::Homepage')
      end

      private

      def make_heading_size_valid
        self.preferred_heading_size = 'small' unless %w[small medium large].include?(preferred_heading_size)
      end

      def make_alignment_valid
        self.preferred_heading_alignment = 'left' unless %w[left center right].include?(preferred_heading_alignment)
      end
    end
  end
end
