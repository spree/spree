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
    class BulkUpsert
      prepend Spree::ServiceModule::Base

      # What the stock history shows against a movement this service wrote.
      FEED_REASON = 'inventory_feed'.freeze

      # @param rows [Array<Hash>] each with +variant_id+, +stock_location_id+,
      #   and either +count_on_hand+ (absolute) or +adjustment+ (relative);
      #   +backorderable+ optional
      # @return [Spree::ServiceModule::Result] +{ stock_level_count: N }+
      def call(rows:)
        rows = Array(rows).map { |row| row.with_indifferent_access }
        keyed = rows.select { |row| row[:variant_id].present? && row[:stock_location_id].present? }
        return success(stock_level_count: 0) if keyed.empty?

        # Last write wins per pair: a feed that mentions the same shelf twice
        # means the later line, not the sum of both.
        deduped = keyed.reverse.uniq { |row| [row[:variant_id].to_s, row[:stock_location_id].to_s] }.reverse

        count = 0
        Spree::StockLevel.transaction do
          deduped.each { |row| count += 1 if apply_row(row) }
        end

        success(stock_level_count: count)
      end

      private

      def apply_row(row)
        stock_level = Spree::StockLevel.find_or_initialize_by(
          variant_id: row[:variant_id], stock_location_id: row[:stock_location_id]
        )
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
