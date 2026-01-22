module Spree
  module PageSections
    class RichText < Spree::PageSection
      def default_blocks
        [
          Spree::PageBlocks::Heading.new(text: Spree.t('page_sections.rich_text.heading_default')),
          Spree::PageBlocks::Text.new(text: Spree.t('page_sections.rich_text.text_default'))
        ]
      end

      def available_blocks_to_add
        [
          Spree::PageBlocks::Heading,
          Spree::PageBlocks::Text
        ]
      end

      def blocks_available?
        true
      end

      def can_sort_blocks?
        true
      end

      def icon_name
        'text-caption'
      end
    end
  end
end
