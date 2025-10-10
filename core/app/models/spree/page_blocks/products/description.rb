module Spree
  module PageBlocks
    module Products
      class Description < Spree::PageBlocks::Text
        TOP_PADDING_DEFAULT = 0
        BOTTOM_PADDING_DEFAULT = 20

        def form_partial_name
          'products/description'
        end

        def display_name
          I18n.t('activerecord.attributes.spree/product.description')
        end
      end
    end
  end
end
