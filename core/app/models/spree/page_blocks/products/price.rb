module Spree
  module PageBlocks
    module Products
      class Price < Spree::PageBlocks::Text
        TOP_PADDING_DEFAULT = 16
        BOTTOM_PADDING_DEFAULT = 16

        def icon_name
          'cash'
        end

        def display_name
          Spree.t(:price)
        end
      end
    end
  end
end
