module Spree
  module PageBlocks
    class Image < Spree::PageBlock
      include Spree::HasImageAltText
      
      alias image asset

      TOP_PADDING_DEFAULT = 20
      BOTTOM_PADDING_DEFAULT = 20

      preference :height, :integer, default: 64
      preference :mobile_height, :integer, default: 32
      preference :image_alt, :string

      def icon_name
        'photo'
      end
    end
  end
end
