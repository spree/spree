module Spree
  module Pages
    class Taxon < Spree::Page
      page_builder_route_with :nested_taxons_path, ->(_) { Spree::Taxon.joins(:products).last || Spree::Taxon.first }

      def icon_name
        'bookmark'
      end

      def default_sections
        [
          Spree::PageSections::TaxonBanner.new,
          Spree::PageSections::ProductGrid.new,
        ]
      end

      def customizable?
        true
      end
    end
  end
end
