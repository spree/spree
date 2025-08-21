module Spree
  module PageSections
    class ImageWithBox < ::Spree::PageSection
      BACKGROUND_COLOR_DEFAULT = 'transparent'
      TEXT_COLOR_DEFAULT = '#000000'
      TOP_PADDING_DEFAULT = '0'
      BOTTOM_PADDING_DEFAULT = '0'
      TOP_BORDER_WIDTH_DEFAULT = '0'
      BOTTOM_BORDER_WIDTH_DEFAULT = '0'

      preference :container_height, :integer, default: 528
      preference :image_size, :string, default: "page-container"
      preference :box_width, :integer, default: 764
      preference :box_alignment_vertical, :string, default: "center"
      preference :box_alignment_horizontal, :string, default: "center"
      preference :box_background_color, :string, default: "#FFFFFF"
      preference :box_top_padding, :integer, default: 32
      preference :box_right_padding, :integer, default: 32
      preference :box_bottom_padding, :integer, default: 32
      preference :box_left_padding, :integer, default: 32

      def icon_name
        'box-margin'
      end

      def blocks_available?
        true
      end

      def available_blocks_to_add
        [Spree::PageBlocks::Heading, Spree::PageBlocks::Text, Spree::PageBlocks::Buttons, Spree::PageBlocks::Image]
      end

      def can_sort_blocks?
        true
      end

      def default_blocks
        @default_blocks.presence || [
          Spree::PageBlocks::Heading.new(
            text: Spree.t('page_sections.image_with_box.heading_default'),
            preferred_background_color: 'transparent',
            preferred_text_alignment: 'center',
            preferred_bottom_padding: 8
          ),
          Spree::PageBlocks::Text.new(
            text: Spree.t('page_sections.image_with_box.text_default'),
            preferred_background_color: 'transparent',
            preferred_text_alignment: 'center',
            preferred_bottom_padding: 24
          ),
          Spree::PageBlocks::Buttons.new
        ]
      end
    end
  end
end