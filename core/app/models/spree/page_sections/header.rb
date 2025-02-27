module Spree
  module PageSections
    class Header < Spree::PageSection
      alias logo asset

      TOP_PADDING_DEFAULT = 15
      BOTTOM_PADDING_DEFAULT = 15
      TOP_BORDER_WIDTH_DEFAULT = 0

      preference :layout, :string, default: 'logo-centered'
      preference :desktop_logo_height, :integer, default: 0

      def self.role
        'header'
      end

      def can_sort_blocks?
        true
      end

      def blocks_available?
        true
      end

      def available_blocks_to_add
        [Spree::PageBlocks::MegaNavWithSubcategories, Spree::PageBlocks::MegaNav, Spree::PageBlocks::Link]
      end

      def icon_name
        'layout-navbar'
      end

      def links_available?
        true
      end

      def default_links
        links = [
          Spree::PageLink.new(linkable: pages.find_by(type: 'Spree::Pages::ShopAll'))
        ]

        collections_taxonomy = store.taxonomies.find_by(name: Spree.t(:taxonomy_collections_name))

        if collections_taxonomy.present?
          on_sale_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.on_sale'))
          new_arrivals_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.new_arrivals'))

          links << Spree::PageLink.new(linkable: on_sale_collection) if on_sale_collection.present?
          links << Spree::PageLink.new(linkable: new_arrivals_collection) if new_arrivals_collection.present?
        end

        links << Spree::PageLink.new(linkable: pages.find_by(type: 'Spree::Pages::PostList'))

        links
      end

      def pages
        @pages ||= theme.pages
      end
    end
  end
end
