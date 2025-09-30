module Spree
  module PageBlocks
    module Products
      class BuyButtons < Spree::PageBlock
        TOP_PADDING_DEFAULT = 0
        BOTTOM_PADDING_DEFAULT = 20

        preference :text_color, :string

        def icon_name
          'shopping-cart-plus'
        end

        def display_name
          Spree.t('page_blocks.products.buy_buttons.display_name')
        end
      end
    end
  end
end
