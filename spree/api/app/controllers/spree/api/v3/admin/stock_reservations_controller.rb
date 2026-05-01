module Spree
  module Api
    module V3
      module Admin
        class StockReservationsController < ResourceController
          scoped_resource :stock

          protected

          def model_class
            Spree::StockReservation
          end

          def serializer_class
            Spree.api.admin_stock_reservation_serializer
          end

          def scope
            Spree::StockReservation.for_store(current_store)
          end

          def collection_includes
            [{ stock_item: [:variant, :stock_location], line_item: [], order: [] }]
          end
        end
      end
    end
  end
end
