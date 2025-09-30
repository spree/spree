module Spree
  module PageBlocks
    module Products
      class Brand < Spree::PageBlocks::Heading
        preference :text_color, :string

        SIZE_DEFAULT = 'medium'

        def display_name
          Spree.t(:brand)
        end
      end
    end
  end
end
