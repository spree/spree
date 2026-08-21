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
      FEED_REASON = 'Inventory feed'.freeze

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

      # How much a feed's row moves the shelf, stated once for both the bulk
      # endpoint and the CSV import: a feed reports either the absolute level
      # its system holds, or a relative movement.
      #
      # @param row [Hash] with +adjustment+ or +count_on_hand+
      # @param current [Integer] what Spree holds now
      # @return [Integer, nil] nil when the row states neither
      def self.delta_for(row, current)
        row = row.with_indifferent_access
        return integer!('adjustment', row[:adjustment]) if row[:adjustment].present?
        return nil if row[:count_on_hand].blank?

        integer!('count_on_hand', row[:count_on_hand]) - current.to_i
      end

      # `to_i` turns "abc" into 0 and "1O" into 1, so a typo in a feed would
      # zero a shelf or set it to a number nobody sent, with no error to notice.
      # A feed must say what it means.
      #
      # @return [Integer]
      # @raise [ArgumentError] when the value is not a whole number
      def self.integer!(column, value)
        Integer(value.to_s.strip, 10)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{column} must be a whole number, got #{value.inspect}"
      end

      private

      def apply_row(row)
        stock_level = Spree::StockLevel.find_or_initialize_by(
          variant_id: row[:variant_id], stock_location_id: row[:stock_location_id]
        )
        stock_level.backorderable = row[:backorderable] if row.key?(:backorderable)
        stock_level.save! if stock_level.new_record? || stock_level.changed?

        # An absolute level is a delta against what Spree holds *now*, so the
        # read and the write must be one step: computing it outside the lock
        # lets two concurrent feeds both measure the same stale count and land
        # the shelf on neither figure.
        moved = false
        stock_level.with_lock do
          delta = delta_for(row, stock_level)
          next if delta.blank? || delta.zero?

          # Through the location's own mover rather than building a movement by
          # hand: it types the row as an adjustment and records the reason, so a
          # feed's correction reads like every other change in the history.
          stock_level.stock_location.adjust(stock_level.variant, delta, reason: FEED_REASON)
          moved = true
        end
        moved
      end

      def delta_for(row, stock_level)
        self.class.delta_for(row, stock_level.count_on_hand)
      end
    end
  end
end
