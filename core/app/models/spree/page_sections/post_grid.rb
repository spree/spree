module Spree
  module PageSections
    class PostGrid < Spree::PageSection
      DISPLAY_NAME = Spree.t(:posts).freeze

      def icon_name
        'news'
      end

      def self.role
        'system'
      end

      def display_name
        DISPLAY_NAME
      end
    end
  end
end
