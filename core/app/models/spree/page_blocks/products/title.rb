module Spree
  module PageBlocks
    module Products
      class Title < Spree::PageBlocks::Heading
        TOP_PADDING_DEFAULT = 16

        preference :text_color, :string

        def display_name
          section.product_name.presence || 'Title'
        end
      end
    end
  end
end
