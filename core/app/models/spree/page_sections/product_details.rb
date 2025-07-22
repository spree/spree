module Spree
  module PageSections
    class ProductDetails < Spree::PageSection
      TOP_PADDING_DEFAULT = 20
      BOTTOM_PADDING_DEFAULT = 40

      def icon_name
        'list-details'
      end

      def self.role
        'system'
      end
    end
  end
end
