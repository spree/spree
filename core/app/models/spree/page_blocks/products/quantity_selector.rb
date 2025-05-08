module Spree
  module PageBlocks
    module Products
      class QuantitySelector < Spree::PageBlock
        TOP_PADDING_DEFAULT = 20
        BOTTOM_PADDING_DEFAULT = 20

        preference :text_color, :string

        def icon_name
          'selector'
        end
      end
    end
  end
end
