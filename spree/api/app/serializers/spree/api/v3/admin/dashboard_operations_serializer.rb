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
            scope = store.orders.complete.not_canceled
            scope = scope.where(channel_id: channel.id) if channel
            scope
          end

          def orders_to_fulfill
            actionable_orders.ready_to_ship.count
          end

          def payments_to_collect
            actionable_orders.where(payment_state: 'balance_due').count
          end

          def open_returns
            scope = store.return_authorizations.where(state: 'authorized')
            scope = scope.where(Spree::Order.table_name => { channel_id: channel.id }) if channel
            scope.count
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

          # `store.stock_items` walks products → variants, so paranoia default
          # scopes already exclude deleted products/variants.
          def tracked_stock_items
            store.stock_items
              .with_active_stock_location
              .where(Spree::Variant.table_name => { track_inventory: true })
          end
        end
      end
    end
  end
end
