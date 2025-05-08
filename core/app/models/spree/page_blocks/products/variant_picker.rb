module Spree
  module PageBlocks
    module Products
      class VariantPicker < Spree::PageBlock
        preference :text_color, :string

        def icon_name
          'select'
        end
      end
    end
  end
end
