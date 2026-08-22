module Spree
  module Imports
    module RowProcessors
      # One row of a stock feed: a shelf, and how many are on it.
      #
      # Writes through a stock movement rather than setting the count, so the
      # merchant can still see why a figure moved after an import.
      class StockLevel < Base
        def process!
          variant = find_variant!
          location = find_stock_location!

          stock_level = Spree::StockLevel.find_or_initialize_by(variant: variant, stock_location: location)
          stock_level.backorderable = attributes['backorderable'].to_b if attributes['backorderable'].present?
          stock_level.save! if stock_level.new_record? || stock_level.changed?

          # Locked around the read for the same reason the bulk endpoint is: an
          # absolute level is a delta against what Spree holds now, and two
          # feeds landing together would otherwise both measure the same stale
          # count.
          stock_level.with_lock do
            delta = delta_for(stock_level)
            next if delta.zero?

            # Through the location's own mover: it types the row as an
            # adjustment and records the reason, so a feed's correction reads
            # like every other change in the stock history.
            location.adjust(variant, delta, reason: Spree::StockLevels::BulkUpsert::FEED_REASON)
          end

          stock_level
        end

        private

        def find_stock_location!
          name = attributes['stock_location'].to_s.strip
          raise ArgumentError, 'Stock location is required' if name.blank?

          location = cached_lookup(:stock_location, name) do
            import.store.stock_locations.find_by(name: name)
          end
          raise ArgumentError, "No stock location named #{name}" if location.nil?

          location
        end

        # The rule lives with the bulk endpoint that shares it — one statement
        # of "absolute level or relative movement" for both feed routes.
        def delta_for(stock_level)
          Spree::StockLevels::BulkUpsert.delta_for(attributes, stock_level.count_on_hand).to_i
        end

      end
    end
  end
end
