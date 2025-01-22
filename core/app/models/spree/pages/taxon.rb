module Spree
  module Pages
    class Taxon < Spree::Page
      def icon_name
        'bookmark'
      end

      def url
        return unless url_exists?(:nested_taxons_path)

        taxon = Spree::Taxon.first
        return if taxon.nil?

        Spree::Core::Engine.routes.url_helpers.nested_taxons_path(taxon, locale: I18n.locale)
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
