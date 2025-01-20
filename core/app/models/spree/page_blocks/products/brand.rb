module Spree
  module PageBlocks
    module Products
      class Brand < Spree::PageBlocks::Text

        def display_name
          section.vendor_name.presence || 'Brand'
        end
      end
    end
  end
end
