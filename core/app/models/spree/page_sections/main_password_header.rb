module Spree
  module PageSections
    class MainPasswordHeader < Spree::PageSection
      alias logo asset

      TOP_PADDING_DEFAULT = 15
      BOTTOM_PADDING_DEFAULT = 15

      preference :desktop_logo_height, :integer, default: 0

      def self.role
        'header'
      end

      def icon_name
        'layout-navbar'
      end
    end
  end
end
