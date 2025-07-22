module Spree
  module PageSections
    class PostDetails < Spree::PageSection
      DISPLAY_NAME = Spree.t(:post).freeze

      def icon_name
        'article'
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
