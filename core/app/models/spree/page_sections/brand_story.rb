module Spree
  module PageSections
    class BrandStory < Spree::PageSection
      BACKGROUND_COLOR_DEFAULT = '#E9E7DC'
      TOP_BORDER_WIDTH_DEFAULT = 0

      def icon_name
        'quote'
      end

      def self.role
        'system'
      end
    end
  end
end
