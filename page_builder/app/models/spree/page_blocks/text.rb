module Spree
  module PageBlocks
    class Text < Spree::PageBlock
      preference :text_color, :string
      preference :background_color, :string

      def icon_name
        'align-justified'
      end

      def display_name
        text.to_plain_text.truncate(30)
      end
    end
  end
end
