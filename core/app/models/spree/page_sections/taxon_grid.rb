module Spree
  module PageSections
    class TaxonGrid < Spree::PageSection
      TOP_BORDER_WIDTH_DEFAULT = 0

      preference :heading, :string, default: Spree.t('page_sections.taxon_grid.heading_default')

      def icon_name
        'layout-grid'
      end

      def self.role
        'system'
      end
    end
  end
end
