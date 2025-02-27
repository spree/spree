module Spree
  module Taxons
    class TouchFeaturedSections
      prepend Spree::ServiceModule::Base

      def call(taxon_ids:)
        return if taxon_ids.empty?

        featured_taxons = Spree::PageSections::FeaturedTaxon.published.by_taxon_id(taxon_ids)

        return if featured_taxons.empty?

        featured_taxons.touch_all
        pages = Spree::Page.where(id: featured_taxons.where(pageable_type: 'Spree::Page').pluck(:pageable_id))
        pages.touch_all
        themes = Spree::Theme.where(id: pages.where(pageable_type: 'Spree::Theme').pluck(:pageable_id).uniq)
        themes.touch_all
      end
    end
  end
end
