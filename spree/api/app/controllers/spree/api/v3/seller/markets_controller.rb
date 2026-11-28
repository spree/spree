module Spree
  module Api
    module V3
      module Seller
        # The marketplace's markets, for a seller choosing where a product may
        # be sold. Read only: which markets exist is the operator's decision.
        class MarketsController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::Market
          end

          def serializer_class
            Spree.api.seller_market_serializer
          end

          def scope
            current_store.markets.ordered
          end

          def collection_includes
            [:market_countries]
          end
        end
      end
    end
  end
end
