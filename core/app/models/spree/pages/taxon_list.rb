module Spree
  module Pages
    class TaxonList < Spree::Page
      DISPLAY_NAME = Spree.t(:taxonomy_brands_name).freeze

      page_builder_route_with :taxonomy_path

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
