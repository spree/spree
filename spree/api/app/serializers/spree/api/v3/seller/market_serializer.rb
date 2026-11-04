module Spree
  module Api
    module V3
      module Seller
        class MarketSerializer < V3::MarketSerializer
          _attributes.delete(:country_isos)
        end
      end
    end
  end
end
