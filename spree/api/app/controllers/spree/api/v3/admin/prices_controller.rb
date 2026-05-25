module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::Price`. Covers both base prices
        # (`price_list_id: nil`) and price-list overrides under one
        # resource, filtered via Ransack predicates on the index.
        class PricesController < ResourceController
          include Spree::Api::V3::BulkOperations

          scoped_resource :products

          before_action :require_ids!, only: [:bulk_destroy]
          before_action :require_prices!, only: [:bulk_upsert]

          # Bulk-upserts prices on the unique-key triple
          # `(variant_id, currency, price_list_id)`.
          #
          # @return [void]
          def bulk_upsert
            authorize! :create, Spree::Price
            authorize! :update, Spree::Price

            rows = Array(params[:prices]).map { |row| decode_price_row(row) }
            invalid = rows.each_with_index.filter_map do |row, idx|
              missing = %i[variant_id currency].reject { |k| row[k].present? }
              { index: idx, missing: missing } if missing.any?
            end
            if invalid.any?
              return render_error(
                code: 'invalid_prices',
                message: 'Each row must include variant_id and currency.',
                status: :unprocessable_content,
                details: { rows: invalid }
              )
            end

            result = Spree::Prices::BulkUpsert.call(rows: rows)
            render json: result.value
          end

          # Soft-deletes the listed prices.
          #
          # @return [void]
          def bulk_destroy
            authorize! :destroy, Spree::Price

            destroy_scope = scope.where(id: decode_ids(params[:ids]))
            destroyed = destroy_scope.count(&:destroy)

            render json: { price_count: destroyed }
          end

          protected

          def model_class
            Spree::Price
          end

          def serializer_class
            Spree.api.admin_price_serializer
          end

          def collection_includes
            {
              variant: [
                :tax_category,
                :prices,
                product: :tax_category,
                option_values: :option_type,
                stock_items: [:stock_location, :active_stock_reservations]
              ]
            }
          end

          # Disabled: Ransack's default `result(distinct: true)` makes
          # Postgres reject `sort=variant_product_name` because the order
          # column isn't in the DISTINCT select list. The store scope
          # already guarantees one Price row per result.
          def collection_distinct?
            false
          end

          def permitted_params
            normalize_params(
              params.permit(:variant_id, :currency, :amount, :compare_at_amount, :price_list_id)
            )
          end

          private

          def bulk_record_count_key
            :price_count
          end

          def require_prices!
            return if params.key?(:prices)

            render_error(
              code: 'missing_prices',
              message: 'prices is required (send an empty array to no-op).',
              status: :unprocessable_content
            )
          end

          def decode_price_row(row)
            row = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
            row = row.with_indifferent_access

            {
              id: decode_id(row[:id]),
              variant_id: decode_id(row[:variant_id]),
              price_list_id: row.key?(:price_list_id) ? decode_id(row[:price_list_id]) : nil,
              currency: row[:currency],
              amount: row[:amount],
              compare_at_amount: row[:compare_at_amount]
            }.compact
          end

          def decode_id(value)
            return nil if value.blank?

            Spree::PrefixedId.prefixed_id?(value) ? Spree::PrefixedId.decode_prefixed_id(value) : value
          end
        end
      end
    end
  end
end
