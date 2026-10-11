module Spree
  module Api
    module V3
      module Seller
        class PriceSerializer < V3::PriceSerializer
          without_formatted_money(:seller)
        end
      end
    end
  end
end
