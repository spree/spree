module Spree
  module PageBlocks
    class Subheading < Spree::PageBlock
      SIZE_DEFAULT = 'small'

      preference :text_color, :string

      def icon_name
        'h2'
      end

      def display_name
        text.to_plain_text.truncate(30)
      end
    end
  end
end
