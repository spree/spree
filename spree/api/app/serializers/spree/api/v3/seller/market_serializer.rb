module Spree
  module Api
    module V3
      module Seller
        # A market a seller can name in a product's market availability.
        class MarketSerializer < V3::MarketSerializer
          _attributes.delete(:country_isos)
        end
      end
    end
  end
end
