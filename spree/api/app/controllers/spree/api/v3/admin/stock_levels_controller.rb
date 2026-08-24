module Spree
  module Api
    module V3
      module Admin
        # Stock levels are auto-created when a variant lands at a stock
        # location, so there's deliberately no `create` route — use the
        # variants / stock-locations endpoints for that flow.
        class StockLevelsController < ResourceController
          scoped_resource :stock

          before_action :require_stock_levels!, only: [:bulk_upsert]

          def bulk_upsert
            authorize! :update, Spree::StockLevel

            raw_rows = Array(params[:stock_levels]).map do |row|
              row = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
              row.with_indifferent_access
            end
            rows = decode_stock_rows(raw_rows)

            invalid = rows.each_with_index.filter_map do |row, index|
              missing = %i[variant_id stock_location_id].reject { |key| row[key].present? }
              missing << :count_on_hand if row[:count_on_hand].blank? && row[:adjustment].blank?
              { index: index, missing: missing } if missing.any?
            end

            if invalid.any?
              return render_error(
                code: 'invalid_stock_levels',
                message: 'Each row must name a variant and stock location in this store, ' \
                         'and either a count_on_hand or an adjustment.',
                status: :unprocessable_content,
                details: { rows: invalid }
              )
            end

            result = Spree::StockLevels::BulkUpsert.call(rows: rows)
            render json: result.value
          end

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
            params.permit(*model_additional_permitted_attributes, :count_on_hand, :backorderable, :reason, metadata: {})
          end

          private

          def require_stock_levels!
            return if params.key?(:stock_levels)

            render_error(
              code: 'missing_stock_levels',
              message: 'stock_levels is required (send an empty array to no-op).',
              status: :unprocessable_content
            )
          end

          # Every id is resolved through the current store's own scopes, so a
          # variant or location belonging to another store is simply not found
          # rather than quietly written to. Rows name records by Spree's own
          # ids alone — this endpoint upserts stock levels, nothing more; a
          # connector resolves its keys through the member paths first.
          #
          # Resolved as a batch: decoding a prefixed id is pure Ruby, so a
          # thousand-row feed costs two SELECTs here, not two per row — and a
          # feed repeats its stock location on nearly every row.
          def decode_stock_rows(raw_rows)
            variant_ids = resolve_ids(store_variants, Spree::Variant, raw_rows.map { |row| row[:variant_id] })
            location_ids = resolve_ids(store_stock_locations, Spree::StockLocation, raw_rows.map { |row| row[:stock_location_id] })

            raw_rows.map do |row|
              {
                variant_id: variant_ids[row[:variant_id]],
                stock_location_id: location_ids[row[:stock_location_id]],
                count_on_hand: row[:count_on_hand],
                adjustment: row[:adjustment],
                backorderable: row[:backorderable]
              }.compact
            end
          end

          # @return [Hash{String=>Integer}] prefixed id => id, for the ids the
          #   scope can actually see; unknown or foreign ids resolve to nothing
          def resolve_ids(scope, model, prefixed_ids)
            decoded = prefixed_ids.uniq.index_with { |value| model.decode_own_prefixed_id(value) }
            found = scope.where(id: decoded.values.compact).pluck(:id).to_set

            decoded.transform_values { |id| id if id && found.include?(id) }
          end

          def store_variants
            current_store.variants.accessible_by(current_ability, :update)
          end

          def store_stock_locations
            current_store.stock_locations.accessible_by(current_ability, :update)
          end
        end
      end
    end
  end
end
