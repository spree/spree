module Spree
  module Prices
    # Bulk-writes Spree::Price rows on the unique key
    # `(variant_id, currency, price_list_id)` and sweeps stale
    # placeholder rows in one transaction.
    #
    # The unique index on `spree_prices` is partial
    # (`WHERE amount IS NOT NULL`), so `upsert_all` can't see
    # placeholder rows (amount IS NULL) as conflict targets — filling
    # in a placeholder via upsert inserts a sibling row instead of
    # updating. The post-write sweep removes those.
    class BulkUpsert
      prepend Spree::ServiceModule::Base

      UNIQUE_BY = %i[variant_id currency price_list_id].freeze

      # @param rows [Array<Hash>] each row must carry
      #   `variant_id`, `currency`, and `amount`; `price_list_id` and
      #   `compare_at_amount` are optional. A blank `amount` is treated
      #   as "clear this price."
      # @return [Spree::ServiceModule::Result] success carries
      #   `{ price_count: N }` — the number of rows passed to
      #   `upsert_all`.
      def call(rows:)
        rows = Array(rows).map { |r| r.with_indifferent_access }
        keyed = rows.select { |r| r[:variant_id].present? && r[:currency].present? }
        # PG rejects an upsert with two rows hitting the same unique-key
        # triple in one statement ("ON CONFLICT DO UPDATE command cannot
        # affect row a second time"). Last-write-wins: keep the last
        # occurrence of each triple.
        deduped = keyed.reverse.uniq { |r| [r[:variant_id], r[:currency], r[:price_list_id]] }.reverse
        upsert_rows, clear_rows = deduped.partition { |r| r[:amount].present? }

        payload = build_payload(upsert_rows)
        affected_keys = deduped.map { |r| [r[:variant_id], r[:currency], r[:price_list_id]] }

        return success(price_count: 0) if affected_keys.empty?

        Spree::Price.transaction do
          # `update_only` lists only domain columns. Rails adds
          # `updated_at` automatically (when `record_timestamps` is on,
          # which it is for `Spree::Price`); listing it explicitly here
          # produces `SET updated_at = …, updated_at = …` on PG and the
          # statement fails with "multiple assignments to same column".
          if payload.any?
            Spree::Price.upsert_all(
              payload,
              update_only: %i[amount compare_at_amount],
              **upsert_opts(UNIQUE_BY)
            )
          end
          sweep(affected_keys, clear_rows)
        end

        success(price_count: payload.length)
      end

      private

      def build_payload(rows)
        now = Time.current
        rows.map do |row|
          {
            variant_id: row[:variant_id],
            currency: row[:currency],
            price_list_id: row[:price_list_id],
            amount: parse_amount(row[:amount]),
            compare_at_amount: parse_amount(row[:compare_at_amount]),
            created_at: now,
            updated_at: now
          }
        end
      end

      # Parses locale-aware decimal input ("1.234,56" in DE, "1,234.56"
      # in en-US). Numeric values pass through; blank values become nil.
      def parse_amount(value)
        return nil if value.blank?
        return value if value.is_a?(Numeric)

        Spree::LocalizedNumber.parse(value)
      end

      def sweep(affected_keys, clear_rows)
        cleared_keys = clear_rows.map { |r| [r[:variant_id], r[:currency], r[:price_list_id]] }.to_set
        affected_set = affected_keys.to_set

        candidates = Spree::Price
          .where(
            variant_id: affected_keys.map(&:first).uniq,
            currency: affected_keys.map { |k| k[1] }.uniq,
            price_list_id: affected_keys.map(&:last).uniq
          )
          .pluck(:id, :variant_id, :currency, :price_list_id, :amount)

        doomed_ids = candidates.filter_map do |id, variant_id, currency, price_list_id, amount|
          key = [variant_id, currency, price_list_id]
          next unless affected_set.include?(key)
          next id if amount.nil?
          next id if cleared_keys.include?(key)

          nil
        end

        Spree::Price.where(id: doomed_ids).delete_all if doomed_ids.any?
      end

      # MySQL infers conflict targets from its own unique indexes and
      # rejects an explicit `unique_by`.
      def upsert_opts(unique_by)
        return {} if ActiveRecord::Base.connection.adapter_name == 'Mysql2'

        { unique_by: unique_by }
      end
    end
  end
end
