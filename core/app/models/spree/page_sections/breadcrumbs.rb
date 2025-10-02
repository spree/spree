module Spree
  module PageSections
    class Breadcrumbs < Spree::PageSection
      TOP_PADDING_DEFAULT = 20
      BOTTOM_PADDING_DEFAULT = 20

      def icon_name
        'chevron-right'
      end
    end
  end
end
