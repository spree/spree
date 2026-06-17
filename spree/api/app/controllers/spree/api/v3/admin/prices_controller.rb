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

            store_variant_ids = store_variants.where(id: rows.map { |r| r[:variant_id] }).ids.map(&:to_s).to_set
            store_price_list_ids = store_price_lists.where(id: rows.filter_map { |r| r[:price_list_id] }).ids.map(&:to_s).to_set
            foreign = rows.each_with_index.filter_map do |row, idx|
              variant_ok = store_variant_ids.include?(row[:variant_id].to_s)
              price_list_ok = row[:price_list_id].blank? || store_price_list_ids.include?(row[:price_list_id].to_s)
              { index: idx } unless variant_ok && price_list_ok
            end
            if foreign.any?
              return render_error(
                code: 'invalid_prices',
                message: 'Each row must reference a variant and price list in the current store.',
                status: :unprocessable_content,
                details: { rows: foreign }
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

          # Resolves variant_id / price_list_id through the current store's
          # scopes so a foreign or unknown id 404s instead of binding the
          # price to another store's record.
          def permitted_params
            permitted = params.permit(:variant_id, :currency, :amount, :compare_at_amount, :price_list_id)
            permitted[:variant_id] = store_variants.find_by_prefix_id!(permitted[:variant_id]).id if permitted[:variant_id].present?
            permitted[:price_list_id] = store_price_lists.find_by_prefix_id!(permitted[:price_list_id]).id if permitted[:price_list_id].present?
            permitted
          end

          private

          def store_variants
            current_store.variants.accessible_by(current_ability, :update)
          end

          def store_price_lists
            current_store.price_lists.accessible_by(current_ability, :update)
          end

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
