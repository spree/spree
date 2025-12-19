module Spree
  module PageBlocks
    class Buttons < Spree::PageBlock
      include Spree::HasOneLink

      TEXT_ALIGNMENT_DEFAULT = 'center'

      preference :button_style_1, :string, default: 'primary'
      preference :background_color, :string
      preference :button_background_color, :string
      preference :button_text_color, :string

      # Without link there is no purpose of the button.
      def link_destroyed(_link)
        return unless page_links_count.zero?

        destroy
      end

      def display_name
        Spree.t('page_blocks.buttons.display_name')
      end

      def icon_name
        'click'
      end
    end
  end
end
