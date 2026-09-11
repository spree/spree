module Spree
  module Api
    module V3
      module Admin
        # Read-only. A movement is a fact about stock that already happened,
        # so it is written by the stock verbs on Spree::StockLocation and
        # never edited — reversing one means writing its counterpart.
        class StockMovementsController < ResourceController
          scoped_resource :stock

          protected

          def model_class
            Spree::StockMovement
          end

          def serializer_class
            Spree.api.admin_stock_movement_serializer
          end

          # Every row names its shelf, its SKU and its cause by number, so all
          # of them come along rather than costing a query each.
          def collection_includes
            [{ stock_level: [:stock_location, { variant: :product }] },
             :order, :return, :exchange, :stock_transfer, :purchase_order]
          end

          # Newest first: a stock history is read from the most recent change
          # backwards.
          def apply_collection_sort(collection)
            collection.recent
          end
        end
      end
    end
  end
end
