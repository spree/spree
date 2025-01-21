module Spree
  module PageSections
    class ProductGrid < Spree::PageSection
      def icon_name
        'layout-grid'
      end

      def self.role
        'system'
      end
    end
  end
end
