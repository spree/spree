module Spree
  module Api
    module V3
      module Admin
        # Builds the home dashboard operations payload: counts of things that
        # need back-office attention right now (not scoped to a date range).
        # A channel narrows the order-derived counts; stock counts stay
        # store-wide since inventory is channel-agnostic.
        class DashboardOperationsSerializer
          DEFAULT_LOW_STOCK_THRESHOLD = 5

          attr_reader :store, :channel, :low_stock_threshold

          def initialize(store:, channel: nil, low_stock_threshold: DEFAULT_LOW_STOCK_THRESHOLD)
            @store = store
            @channel = channel
            @low_stock_threshold = low_stock_threshold
          end

          def to_h
            {
              channel_id: channel&.prefixed_id,
              low_stock_threshold: low_stock_threshold,
              orders_to_fulfill: orders_to_fulfill,
              payments_to_collect: payments_to_collect,
              open_returns: open_returns,
              low_stock_items: low_stock_items,
              out_of_stock_items: out_of_stock_items
            }
          end

          private

          def actionable_orders
            store.orders.complete.not_canceled.for_channel(channel)
          end

          def orders_to_fulfill
            actionable_orders.ready_to_ship.count
          end

          # Placed orders still owed money: nothing collected yet, authorized but
          # not captured, or only partially paid.
          def payments_to_collect
            actionable_orders.where(payment_status: %w[none authorized partially_paid]).count
          end

          def open_returns
            store.returns
              .joins(:order)
              .where(status: %w[requested approved])
              .merge(Spree::Order.for_channel(channel))
              .count
          end

          def low_stock_items
            tracked_stock_items
              .where(count_on_hand: 1..low_stock_threshold)
              .distinct
              .count(:variant_id)
          end

          def out_of_stock_items
            tracked_stock_items
              .where(count_on_hand: ..0)
              .distinct
              .count(:variant_id)
          end

          # `store.stock_levels` walks products → variants, so paranoia default
          # scopes already exclude deleted products/variants.
          def tracked_stock_items
            store.stock_levels
              .with_active_stock_location
              .where(Spree::Variant.table_name => { track_inventory: true })
          end
        end
      end
    end
  end
end
