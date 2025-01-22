module Spree
  module Pages
    class TaxonList < Spree::Page
      DISPLAY_NAME = Spree.t(:taxonomy_brands_name).freeze

      def url
        return unless url_exists?(:taxonomy_path)

        Spree::Core::Engine.routes.url_helpers.taxonomy_path(taxonomy.id, locale: I18n.locale)
      end

      def icon_name
        'sort-a-z'
      end

      def default_sections
        [
          Spree::PageSections::TaxonGrid.new,
        ]
      end

      def customizable?
        true
      end

      def display_name
        DISPLAY_NAME
      end

      def taxonomy_id
        settings['taxonomy_id'].presence || store.taxonomies.first&.id
      end

      def taxonomy
        @taxonomy ||= store.taxonomies.find(taxonomy_id)
      end
    end
  end
end
