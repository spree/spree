module Spree
  module StockLevels
    # Corrects one shelf to a counted figure, or by a counted difference.
    #
    # This is what a merchant does after counting: they know what is on the
    # shelf ("set it to 40"), or what changed ("two fewer, damaged"). Either
    # way the change is written as an `adjusted` movement carrying the delta,
    # never onto the column, so the stock history explains every figure it
    # shows.
    #
    # Shared by the single-level endpoint and {Spree::StockLevels::BulkUpsert},
    # so a feed's row and an admin's edit obey one set of rules.
    class Correct
      prepend Spree::ServiceModule::Base

      # @param stock_level [Spree::StockLevel]
      # @param count_on_hand [Integer, String, nil] the figure the shelf should
      #   end at
      # @param adjustment [Integer, String, nil] a signed change instead, for a
      #   caller who knows the difference but not the current count
      # @param reason [String, Symbol, nil] why, for the stock history. A key
      #   from {Spree::StockMovement::ADJUSTMENT_REASONS} is resolved to its
      #   English text; anything else is stored as given
      # @return [Spree::ServiceModule::Result] the corrected stock level
      def call(stock_level:, count_on_hand: nil, adjustment: nil, reason: nil)
        if count_on_hand.present? && adjustment.present?
          return failure(stock_level, Spree.t('stock_level.errors.adjustment_exclusive_with_count_on_hand'))
        end

        target = parse(count_on_hand)
        delta = parse(adjustment)
        return failure(stock_level, Spree.t('stock_level.errors.count_on_hand_not_an_integer')) if count_on_hand.present? && target.nil?
        return failure(stock_level, Spree.t('stock_level.errors.adjustment_not_an_integer')) if adjustment.present? && delta.nil?

        # Locked around the read: the delta is worked out from the count this
        # caller first saw, so two admins correcting the same level at once
        # would otherwise each measure against a shelf the other had already
        # moved, and both edits would land.
        stock_level.with_lock do
          move = delta || (target && target - stock_level.count_on_hand)
          next if move.nil? || move.zero?

          # Through the location's own mover rather than building a movement
          # by hand: it types the row as an adjustment and records the reason,
          # so a correction reads like every other change in the history.
          stock_level.stock_location.adjust(stock_level.variant, move,
                                            reason: Spree::StockMovement.adjustment_reason_text(reason))
        end

        success(stock_level.reload)
      end

      private

      # Strictly, because `to_i` reads anything unparseable as zero — and a
      # zero here is not a no-op but an instruction to write the whole shelf
      # off. A typo must be refused, never obeyed. Base ten explicitly, or a
      # feed's zero-padded "010" would be read as octal and land as eight.
      #
      # @return [Integer, nil] nil when the value is not a whole number
      def parse(value)
        return nil if value.nil?
        return value if value.is_a?(Integer)

        Integer(value.to_s.strip, 10, exception: false)
      end
    end
  end
end
