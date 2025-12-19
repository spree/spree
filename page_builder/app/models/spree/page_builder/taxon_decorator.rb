module Spree
  module PageBuilder
    module TaxonDecorator
      def self.prepended(base)
        base.include Spree::Linkable

        base.class_eval do
          after_commit :touch_featured_sections, on: [:update]
          after_touch :touch_featured_sections
          after_destroy :remove_featured_sections, if: -> { featured? }
        end
      end

      def page_builder_url
        return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:nested_taxons_path)

        Spree::Core::Engine.routes.url_helpers.nested_taxons_path(self)
      end

      def page_builder_image
        square_image.presence || image
      end

      def featured?
        featured_sections.any?
      end

      def featured_sections
        @featured_sections ||= Spree::PageSections::FeaturedTaxon.published.by_taxon_id(id)
      end

      private

      def touch_featured_sections
        Spree::Taxons::TouchFeaturedSections.call(taxon_ids: [id])
      end

      def remove_featured_sections
        featured_sections.destroy_all
      end
    end
  end
end

Spree::Taxon.prepend(Spree::PageBuilder::TaxonDecorator)
