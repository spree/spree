module Spree
  module Api
    module V3
      module Admin
        # Stock levels are auto-created when a variant lands at a stock
        # location, so there's deliberately no `create` route — use the
        # variants / stock-locations endpoints for that flow.
        class StockLevelsController < ResourceController
          scoped_resource :stock

          # PATCH /api/v3/admin/stock_levels/:id
          #
          # A count edit is a correction, so it is written as an `adjusted`
          # movement rather than straight onto the column — that is what puts
          # it in the stock history beside every other change. The rest of the
          # payload updates normally.
          def update
            attributes = permitted_params.to_h
            new_count = attributes.delete('count_on_hand')
            reason = attributes.delete('reason').presence || Spree::StockMovement.default_adjustment_reason

            ActiveRecord::Base.transaction do
              @resource.update!(attributes) if attributes.any?
              adjust_count_on_hand(new_count, reason) unless new_count.nil?
            end

            render json: serialize_resource(@resource.reload)
          rescue ActiveRecord::RecordInvalid => e
            render_errors(e.record.errors)
          end

          protected

          # The movement carries the delta, not the new count — it records what
          # changed, and the column follows from it.
          def adjust_count_on_hand(new_count, reason)
            delta = new_count.to_i - @resource.count_on_hand
            return if delta.zero?

            @resource.stock_location.adjust(@resource.variant, delta, reason: reason)
          end

          def model_class
            Spree::StockLevel
          end

          def serializer_class
            Spree.api.admin_stock_level_serializer
          end

          def collection_includes
            [:stock_location, :variant]
          end

          # `StockLevel.for_store` already applies its own `distinct`, and
          # `id`-asc gives a stable order across edits (variant.position
          # alone isn't unique — see git blame for the row-jumping bug).
          def apply_collection_sort(collection)
            collection.order(Spree::StockLevel.arel_table[:id].asc)
          end

          # Stock levels are auto-created against a (variant, stock_location)
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
