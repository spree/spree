module Spree
  module PageSections
    class Footer < Spree::PageSection
      alias logo asset

      BACKGROUND_COLOR_DEFAULT = '#F5F5F4'
      TOP_PADDING_DEFAULT = 32
      BOTTOM_PADDING_DEFAULT = 32
      TOP_BORDER_WIDTH_DEFAULT = 0

      preference :copyright_text_color, :string, default: '#FFFFFF'
      preference :copyright_background_color, :string, default: '#000000'

      def self.role
        'footer'
      end

      def icon_name
        'layout-bottombar'
      end

      def can_sort_blocks?
        true
      end

      def blocks_available?
        true
      end

      def available_blocks_to_add
        [Spree::PageBlocks::Nav]
      end

      def default_blocks
        shop_default_links = [
          Spree::PageLink.new(
            linkable: pages.find_by(type: 'Spree::Pages::ShopAll')
          )
        ]

        collections_taxonomy = store.taxonomies.find_by(name: Spree.t(:taxonomy_collections_name))

        if collections_taxonomy.present?
          on_sale_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.on_sale'))
          new_arrivals_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.new_arrivals'))

          shop_default_links << Spree::PageLink.new(linkable: on_sale_collection) if on_sale_collection.present?
          shop_default_links << Spree::PageLink.new(linkable: new_arrivals_collection) if new_arrivals_collection.present?
        end

        default_info_links = []

        if store.policies.find_by(name: Spree.t('terms_of_service')).present?
          default_info_links << Spree::PageLink.new(
            label: Spree.t('terms_of_service'),
            linkable: store.policies.find_by(name: Spree.t('terms_of_service'))
          )
        end

        if store.policies.find_by(name: Spree.t('privacy_policy')).present?
          default_info_links << Spree::PageLink.new(
            label: Spree.t('privacy_policy'),
            linkable: store.policies.find_by(name: Spree.t('privacy_policy'))
          )
        end

        [
          Spree::PageBlocks::Nav.new(
            preferred_label: 'Shop',
            default_links: shop_default_links
          ),
          Spree::PageBlocks::Nav.new(
            preferred_label: Spree.t('account'),
            default_links: [
              Spree::PageLink.new(
                label: Spree.t('my_account'),
                linkable: pages.find_by(type: 'Spree::Pages::Account')
              ),
              Spree::PageLink.new(
                label: 'Favorites',
                linkable: pages.find_by(type: 'Spree::Pages::Wishlist')
              )
            ]
          ),
          Spree::PageBlocks::Nav.new(
            preferred_label: 'Company',
            default_links: []
          ),
          Spree::PageBlocks::Nav.new(
            preferred_label: 'Info',
            default_links: default_info_links
          )
        ]
      end

      def pages
        @pages ||= theme.pages
      end
    end
  end
end
