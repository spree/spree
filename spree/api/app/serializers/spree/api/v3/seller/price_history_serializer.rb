module Spree
  module Api
    module V3
      module Seller
        class PriceHistorySerializer < V3::PriceHistorySerializer
          without_formatted_money(:seller)
        end
      end
    end
  end
end
