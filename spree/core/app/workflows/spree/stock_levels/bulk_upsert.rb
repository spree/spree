module Spree
  module StockLevels
    # Sets stock levels for many (variant, location) pairs in one call — what a
    # warehouse feed posts on a schedule.
    #
    # Deliberately not an +upsert_all+. Stock changes are recorded as movements
    # so a merchant can see why a figure changed, and writing +count_on_hand+
    # straight would leave that history with a hole in it. The cost is a row
    # per change rather than one statement; the alternative is stock that
    # cannot be explained.
    #
    # A feed states absolute levels (+count_on_hand+), which is what an
    # external system knows. The movement records the delta between what Spree
    # held and what the feed says.
    class BulkUpsert < Spree::Workflow

      # What the stock history shows against a movement this service wrote.
      FEED_REASON = 'inventory_feed'.freeze

      # @param store [Spree::Store] whose shelves these are. Ids are resolved
      #   through it, so a row naming another store's variant is not found
      #   rather than written.
      # @param rows [Array<Hash>] one per shelf: +variant_id+ and
      #   +stock_location_id+ naming it (prefixed ids, or raw), then either
      #   +count_on_hand+ (the figure it should end at) or +adjustment+ (a
      #   signed change); +backorderable+ optional
      # @return [Spree::ServiceModule::Result] +{ stock_level_count: N }+
      def perform(store:, rows:)
        @store = store
        rows = resolve(Array(rows).map { |row| row.with_indifferent_access })
        keyed = rows.select { |row| row[:variant_id].present? && row[:stock_location_id].present? }
        return success(stock_level_count: 0) if keyed.empty?

        # Last write wins per pair: a feed that mentions the same shelf twice
        # means the later line, not the sum of both.
        deduped = keyed.reverse.uniq { |row| [row[:variant_id].to_s, row[:stock_location_id].to_s] }.reverse

        existing = existing_stock_levels(deduped)
        count = 0
        Spree::StockLevel.transaction do
          deduped.each { |row| count += 1 if apply_row(row, existing) }
        end

        success(stock_level_count: count)
      end

      private

      # Names become this store's own ids, or nothing.
      #
      # Resolved here rather than by the caller, because a row reaching
      # `find_or_initialize_by` unscoped writes to whichever shelf the id
      # happens to name — including another merchant's. One caller decoding
      # ids correctly does not make the workflow safe for the next one.
      def resolve(rows)
        @variants = scoped_records(store_variants, Spree::Variant, rows.map { |row| row[:variant_id] })
        @stock_locations = scoped_records(store_stock_locations, Spree::StockLocation,
                                          rows.map { |row| row[:stock_location_id] })
        @variants_by_id = @variants.values.index_by(&:id)
        @stock_locations_by_id = @stock_locations.values.index_by(&:id)

        rows.map do |row|
          row.merge(
            variant_id: @variants[row[:variant_id]]&.id,
            stock_location_id: @stock_locations[row[:stock_location_id]]&.id
          ).compact
        end
      end

      # Accepts a prefixed id or a raw one: the Admin API speaks prefixed,
      # while the importer and seeds hold records they already loaded.
      #
      # @return [Hash{Object => ActiveRecord::Base}] each value as given => this store's record
      def scoped_records(scope, model, values)
        decoded = values.compact.uniq.index_with do |value|
          model.decode_own_prefixed_id(value) || value
        end
        found = scope.where(id: decoded.values.compact).index_by { |record| record.id.to_s }

        decoded.transform_values { |id| found[id.to_s] if id }.compact
      end

      # Every shelf the feed names, in one query rather than one per row.
      # Lowest id wins, as an unordered lookup per pair would return.
      def existing_stock_levels(rows)
        Spree::StockLevel.
          where(variant_id: rows.map { |row| row[:variant_id] }.uniq,
                stock_location_id: rows.map { |row| row[:stock_location_id] }.uniq).
          order(id: :desc).
          index_by { |stock_level| [stock_level.variant_id.to_s, stock_level.stock_location_id.to_s] }
      end

      def store_variants
        @store.variants
      end

      def store_stock_locations
        @store.stock_locations
      end

      def apply_row(row, existing)
        stock_level = existing[[row[:variant_id].to_s, row[:stock_location_id].to_s]] || Spree::StockLevel.new
        stock_level.variant = @variants_by_id.fetch(row[:variant_id])
        stock_level.stock_location = @stock_locations_by_id.fetch(row[:stock_location_id])
        stock_level.backorderable = row[:backorderable] if row.key?(:backorderable)
        stock_level.save! if stock_level.new_record? || stock_level.changed?

        before = stock_level.count_on_hand
        result = Spree.stock_level_correct_service.call(
          stock_level: stock_level,
          count_on_hand: row[:count_on_hand],
          adjustment: row[:adjustment],
          reason: FEED_REASON
        )
        # A feed that states a figure Spree cannot read means a typo, and a
        # typo must be refused rather than obeyed: `to_i` would zero a shelf
        # or set it to a number nobody sent.
        raise ArgumentError, result.error.to_s if result.failure?

        result.value.count_on_hand != before
      end
    end
  end
end
