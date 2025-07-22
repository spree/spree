module Spree
  module PageSections
    class Newsletter < Spree::PageSection
      preference :overlay_transparency, :integer, default: 40

      def default_blocks
        @default_blocks.presence || [
          Spree::PageBlocks::Heading.new(
            text: Spree.t('page_sections.newsletter.heading_default'),
            preferred_width_desktop: 50, # in %
            preferred_text_alignment: 'center',
            preferred_container_alignment: 'center',
            preferred_bottom_padding: 8
          ),
          Spree::PageBlocks::Text.new(
            text: Spree.t('page_sections.newsletter.text_default'),
            preferred_text_alignment: 'center',
            preferred_bottom_padding: 32,
            preferred_width_desktop: 50,
            preferred_container_alignment: 'center'
          ),
          Spree::PageBlocks::NewsletterForm.new
        ]
      end

      def self.role
        'footer'
      end

      def blocks_available?
        true
      end

      def available_blocks_to_add
        [Spree::PageBlocks::Image, Spree::PageBlocks::Heading, Spree::PageBlocks::Text, Spree::PageBlocks::NewsletterForm]
      end

      def can_sort_blocks?
        true
      end

      def icon_name
        'mail'
      end
    end
  end
end
