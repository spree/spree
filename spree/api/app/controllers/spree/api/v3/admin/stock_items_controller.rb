module Spree
  module Api
    module V3
      module Admin
        # Stock items are auto-created when a variant lands at a stock
        # location, so there's deliberately no `create` route — use the
        # variants / stock-locations endpoints for that flow.
        class StockItemsController < ResourceController
          scoped_resource :stock

          protected

          def model_class
            Spree::StockItem
          end

          def serializer_class
            Spree.api.admin_stock_item_serializer
          end

          def collection_includes
            [:stock_location, :variant]
          end

          # `StockItem.for_store` already applies its own `distinct`, and
          # `id`-asc gives a stable order across edits (variant.position
          # alone isn't unique — see git blame for the row-jumping bug).
          def apply_collection_sort(collection)
            collection.order(Spree::StockItem.arel_table[:id].asc)
          end

          # Stock items are auto-created against a (variant, stock_location)
          # pair and never re-pointed, so update only touches the count and
          # backorder flag — not the variant or location FKs.
          def permitted_params
            params.permit(:count_on_hand, :backorderable, metadata: {})
          end
        end
      end
    end
  end
end
