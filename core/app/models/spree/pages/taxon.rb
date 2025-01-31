module Spree
  module Pages
    class Taxon < Spree::Page
      def icon_name
        'bookmark'
      end

      def page_builder_url
        return unless page_builder_url_exists?(:nested_taxons_path)

        taxon = Spree::Taxon.first
        return if taxon.nil?

        Spree::Core::Engine.routes.url_helpers.nested_taxons_path(taxon)
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
