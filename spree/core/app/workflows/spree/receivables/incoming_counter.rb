module Spree
  module Receivables
    # The one path that moves a document's awaited units on and off the
    # destination's `incoming_count`. A purchase order or transfer counts
    # toward incoming exactly while it is `incoming?` — `ordered`,
    # `in_transit`, `partially_received` — so the workflow that takes it into
    # that set adds every line's units, and the one that takes it out
    # withdraws whatever is still awaited. Nothing else writes the counter.
    module IncomingCounter
      private

      def count_incoming(receivable)
        move_incoming(receivable, 1)
      end

      # Only a document that was counted can be uncounted: a cancelled draft
      # never put anything on its way.
      def uncount_incoming(receivable)
        return unless receivable.incoming?

        move_incoming(receivable, -1)
      end

      # The lines are read afresh here rather than from whatever the caller
      # loaded before taking the document lock, since a delivery committed in
      # between changes what is still awaited. The destination level is
      # created when the warehouse has never held the SKU: a merchant who has
      # ordered twenty of something new should see them on their way.
      def move_incoming(receivable, sign)
        destination = receivable.destination_location
        lines = receivable.items.includes(:variant).to_a
        levels = destination.stock_levels.where(variant_id: lines.map(&:variant_id)).index_by(&:variant_id)

        lines.each do |item|
          units = item.incoming
          next if units.zero?

          level = levels[item.variant_id] || destination.stock_level_or_create(item.variant)
          level.adjust_incoming_count(sign * units)
        end
      end
    end
  end
end
