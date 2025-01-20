module Spree
  module PageBlocks
    class MegaNav < Spree::PageBlock
      include Spree::HasPageLinks

      has_one :link, ->(ps) { ps.links.where(position: 1) }, class_name: 'Spree::PageLink', as: :parent, dependent: :destroy, inverse_of: :parent
      accepts_nested_attributes_for :link

      preference :featured_taxon_id, :string, default: ''

      def featured_taxon
        store.taxons.find_by(id: preferred_featured_taxon_id) if preferred_featured_taxon_id.present?
      end

      def icon_name
        'layout-navbar-expand'
      end

      def display_name
        link&.label || Spree.t(:mega_nav)
      end

      def default_links
        @default_links.presence || [
          Spree::PageLink.new(
            label: Spree.t(:shop_all),
            linkable: theme_or_parent.pages.find_by(type: 'Spree::Pages::ShopAll')
          ),
        ]
      end
    end
  end
end
