module Spree
  module PageSections
    class ImageWithText < Spree::PageSection
      include Spree::HasImageAltText
      
      TOP_PADDING_DEFAULT = 16
      BOTTOM_PADDING_DEFAULT = 16

      preference :desktop_image_alignment, :string, default: 'right'
      preference :vertical_alignment, :string, default: :middle
      preference :image_alt, :string

      has_one :link, ->(ps) { ps.links }, class_name: 'Spree::PageLink', as: :parent, dependent: :destroy, inverse_of: :parent
      accepts_nested_attributes_for :link

      def default_blocks
        @default_blocks.presence || [
          Spree::PageBlocks::Heading.new(
            text: Spree.t('page_sections.image_with_text.heading_default'),
            preferred_text_alignment: 'left',
            preferred_bottom_padding: 8,
            preferred_top_padding: 24
          ),
          Spree::PageBlocks::Text.new(
            text: Spree.t('page_sections.image_with_text.text_default', store_name: store.name),
            preferred_text_alignment: 'left',
            preferred_bottom_padding: 16
          ),
          Spree::PageBlocks::Buttons.new(preferred_text_alignment: 'left')
        ]
      end

      def available_blocks_to_add
        [
          Spree::PageBlocks::Buttons,
          Spree::PageBlocks::Heading,
          Spree::PageBlocks::Text
        ]
      end

      def default_links
        @default_links.presence || [
          Spree::PageLink.new(
            label: Spree.t(:shop_all),
            linkable: theme.pages.find_by(type: 'Spree::Pages::ShopAll')
          )
        ]
      end

      def blocks_available?
        true
      end

      def can_sort_blocks?
        true
      end

      def icon_name
        'photo'
      end


    end
  end
end
