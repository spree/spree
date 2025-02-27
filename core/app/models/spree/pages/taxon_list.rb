module Spree
  module Pages
    class TaxonList < Spree::Page
      DISPLAY_NAME = Spree.t(:taxonomy_brands_name).freeze


      def page_builder_url
        return unless page_builder_url_exists?(:taxonomy_path)

        Spree::Core::Engine.routes.url_helpers.taxonomy_path(taxonomy.id)
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
        false
      end

      def display_name
        DISPLAY_NAME
      end

      # FIXME: this should use preferences
      def taxonomy_id
        store.taxonomies.first&.id
      end

      def taxonomy
        @taxonomy ||= store.taxonomies.find(taxonomy_id)
      end
    end
  end
end
