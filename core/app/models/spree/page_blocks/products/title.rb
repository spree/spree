module Spree
  module PageBlocks
    module Products
      class Title < Spree::PageBlocks::Heading
        TOP_PADDING_DEFAULT = 16

        preference :text_color, :string

        def display_name
          I18n.t('activerecord.attributes.spree/product.name')
        end

        def icon_name
          'h-1'
        end
      end
    end
  end
end
