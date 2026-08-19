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

            unless new_count.nil?
              new_count = parse_count(new_count)
              return render_validation_error(count_on_hand_errors) if new_count.nil?
            end

            # Locked around the read: the delta is worked out from the count
            # this request first saw, so two admins correcting the same level at
            # once would otherwise each apply a delta measured against a shelf
            # the other had already moved, and both edits would land.
            @resource.with_lock do
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
            delta = new_count - @resource.count_on_hand
            return if delta.zero?

            @resource.stock_location.adjust(@resource.variant, delta, reason: reason)
          end

          # Strictly, because `to_i` reads anything unparseable as zero — and a
          # zero here is not a no-op but an instruction to write the whole shelf
          # off. A typo must be refused, never obeyed.
          #
          # @return [Integer, nil] nil when the value is not a whole number
          def parse_count(value)
            return value if value.is_a?(Integer)

            Integer(value.to_s.strip, exception: false)
          end

          def count_on_hand_errors
            Spree::StockLevel.new.errors.tap do |errors|
              errors.add(:count_on_hand, :not_an_integer)
            end
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
          #
          # `reason` labels the correction in the stock history. It stays
          # optional so an audit requirement never turns an existing endpoint
          # into a 422; omitting it falls back to a translated default.
          def permitted_params
            params.permit(:count_on_hand, :backorderable, :reason, metadata: {})
          end
        end
      end
    end
  end
end
