module Spree
  module PageBlocks
    module Products
      class QuantitySelector < Spree::PageBlock
        TOP_PADDING_DEFAULT = 0
        BOTTOM_PADDING_DEFAULT = 20

        preference :text_color, :string

        def icon_name
          'plus-minus'
        end

        def form_partial_name
          'products/quantity_selector'
        end
      end
    end
  end
end
