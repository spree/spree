module Spree
  module PageSections
    class AnnouncementBar < Spree::PageSection
      has_rich_text :text

      before_validation :set_default_text, on: :create

      BACKGROUND_COLOR_DEFAULT = '#F5F5F4'
      TOP_PADDING_DEFAULT = 8
      BOTTOM_PADDING_DEFAULT = 8
      TOP_BORDER_WIDTH_DEFAULT = 0

      def self.role
        'header'
      end

      def icon_name
        'speakerphone'
      end

      private

      def set_default_text
        return unless text.blank?

        self.text = Spree.t('page_sections.announcement_bar.default_text')
      end
    end
  end
end
