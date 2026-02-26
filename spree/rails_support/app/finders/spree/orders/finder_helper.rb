module Spree
  module Orders
    module FinderHelper
      def order_includes
        {
          line_items: [
            variant: [
              :product,
              :images,
              { option_values: :option_type }
            ]
          ]
        }
      end
    end
  end
end
