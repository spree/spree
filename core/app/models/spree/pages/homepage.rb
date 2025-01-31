module Spree
  module Pages
    class Homepage < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:root_path)

        Spree::Core::Engine.routes.url_helpers.root_path
      end

      def icon_name
        'home'
      end

      def default_sections
        sections = [
          Spree::PageSections::ImageWithText.new(
            preferred_top_padding: 0,
            preferred_bottom_padding: 26
          )
        ]

        collections_taxonomy = store.taxonomies.find_by(name: Spree.t(:taxonomy_collections_name))

        if collections_taxonomy.present?
          on_sale_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.on_sale'))
          new_arrivals_collection = collections_taxonomy.taxons.automatic.find_by(name: Spree.t('automatic_taxon_names.new_arrivals'))

          if on_sale_collection.present?
            sections << Spree::PageSections::FeaturedTaxon.new(
              preferred_heading: Spree.t('pages_defaults.homepage.featured_taxon_heading_on_sale'),
              preferred_use_description_from_admin: true,
              preferred_taxon_id: on_sale_collection.id
            )
          end

          if new_arrivals_collection.present?
            sections << Spree::PageSections::FeaturedTaxon.new(
              preferred_heading: Spree.t('pages_defaults.homepage.featured_taxon_heading_new_arrivals'),
              preferred_use_description_from_admin: true,
              preferred_taxon_id: new_arrivals_collection.id
            )
          end
        end

        sections << Spree::PageSections::ImageWithText.new(
          preferred_background_color: '#F0EFE9', # accent color,
          default_blocks: [
            Spree::PageBlocks::Heading.new(
              text: Spree.t('pages_defaults.homepage.image_with_text_heading'),
              preferred_text_alignment: 'left',
              preferred_bottom_padding: 8,
              preferred_top_padding: 24
            ),
            Spree::PageBlocks::Text.new(
              text: Spree.t('pages_defaults.homepage.image_with_text_text'),
              preferred_text_alignment: 'left',
              preferred_bottom_padding: 16
            )
          ]
        )
      end

      def customizable?
        true
      end
    end
  end
end
