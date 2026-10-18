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

          # Stock levels are auto-created against a (variant, stock_location)
          # pair and never re-pointed, so update only touches the count and
          # backorder flag, not the variant or location.
          request_params :stock_level do |body|
            body.external_references
            body.attribute :count_on_hand, :integer,
              description: 'The count the shelf should end at: a whole number of zero or more. The API records the difference as an `adjusted` movement, so the correction appears in the stock history.'
            body.attribute :adjustment, :integer,
              description: 'A signed change to the shelf instead of a target count, applied to the count the API holds at that moment and recorded the same way. Cannot be sent together with `count_on_hand`.'
            body.attribute :backorderable, :boolean,
              description: 'Whether this location sells the variant beyond what it holds.'
            # Optional so an audit requirement never turns an existing
            # endpoint into a 422.
            body.attribute :reason, :string,
              description: 'Labels the correction in the stock history. Defaults to "Manual adjustment".'
            body.attribute :metadata, :hash
          end

          request_params 'StockLevelBulkUpsertParams', action: :bulk_upsert do |body|
            body.attribute :stock_levels, :array,
              required: true,
              as: 'StockLevelBulkUpsertRowParams',
              description: 'Send an empty list to change nothing.' do |stock_level|
              stock_level.attribute :variant_id, :id, required: true, example: 'variant_xY9'
              stock_level.attribute :stock_location_id, :id, required: true, example: 'sloc_aBc'
              stock_level.attribute :count_on_hand, :integer,
                nullable: true,
                example: 42,
                description: 'The absolute level the external system reports.'
              stock_level.attribute :adjustment, :integer,
                nullable: true,
                example: -3,
                description: 'A relative change, for feeds that report movements rather than levels. Each row needs `count_on_hand` or `adjustment`.'
              stock_level.attribute :backorderable, :boolean, nullable: true
            end
          end

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

            result = Spree.stock_level_bulk_upsert_workflow.call(store: current_store, rows: rows)
            render json: result.value
          end

          # PATCH /api/v3/admin/stock_levels/:id
          #
          # A count edit is a correction written as an `adjusted` movement
          # rather than straight onto the column, which is what puts it in the
          # stock history beside every other change — see
          # {Spree::StockLevels::Correct}. The rest of the payload updates
          # normally.
          #
          # Both halves share one transaction: a refused correction — a
          # non-integer count, or a count and an adjustment together — must
          # not leave the backorder flag or the metadata from the same request
          # committed behind a 422.
          def update
            attributes = permitted_params.to_h
            correction = attributes.extract!('count_on_hand', 'adjustment', 'reason')
            result = nil

            model_class.transaction do
              @resource.update!(attributes) if attributes.any?

              result = Spree.stock_level_correct_service.call(
                stock_level: @resource,
                count_on_hand: correction['count_on_hand'],
                adjustment: correction['adjustment'],
                reason: correction['reason']
              )
              raise ActiveRecord::Rollback if result.failure?
            end

            if result.failure?
              @resource.reload
              return render_validation_error(result.error.to_s)
            end

            render json: serialize_resource(result.value)
          rescue ActiveRecord::RecordInvalid => e
            render_errors(e.record.errors)
          end

          protected

          def model_class
            Spree::StockLevel
          end

          def serializer_class
            Spree.api.admin_stock_level_serializer
          end

          # What the flat row attributes read, so a page of levels is a fixed
          # number of queries however long it is.
          def collection_includes
            [:stock_location, { variant: [:primary_media, { option_values: :option_type }, { product: :primary_media }] }]
          end

          # `StockLevel.for_store` already applies its own `distinct`, and
          # `id`-asc gives a stable order across edits (variant.position
          # alone isn't unique — see git blame for the row-jumping bug).
          def apply_collection_sort(collection)
            collection.order(Spree::StockLevel.arel_table[:id].asc)
          end

          def permitted_params
            params.permit(*permitted_attributes)
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
