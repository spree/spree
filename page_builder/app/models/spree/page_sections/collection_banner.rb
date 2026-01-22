module Spree
  module PageSections
    class CollectionBanner < Spree::PageSection
      TOP_PADDING_DEFAULT = 20
      BOTTOM_PADDING_DEFAULT = 20
      TOP_BORDER_WIDTH_DEFAULT = 0
      BOTTOM_BORDER_WIDTH_DEFAULT = 1

      def icon_name
        'heading'
      end

      def self.role
        'system'
      end
    end
  end
end
