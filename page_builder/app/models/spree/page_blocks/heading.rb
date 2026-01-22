module Spree
  module PageBlocks
    class Heading < Spree::PageBlock
      SIZE_DEFAULT = 'large'

      preference :text_color, :string
      preference :background_color, :string

      def icon_name
        'heading'
      end

      def display_name
        text.to_plain_text.truncate(30)
      end
    end
  end
end
