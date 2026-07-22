module Spree
  module Api
    module V3
      module Admin
        # Builds the home dashboard operations payload: counts of things that
        # need back-office attention right now (not scoped to a date range).
        class DashboardOperationsSerializer
          DEFAULT_LOW_STOCK_THRESHOLD = 5

          attr_reader :store, :low_stock_threshold

          def initialize(store:, low_stock_threshold: DEFAULT_LOW_STOCK_THRESHOLD)
            @store = store
            @low_stock_threshold = low_stock_threshold
          end

          def to_h
            {
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
            store.orders.complete.not_canceled
          end

          def orders_to_fulfill
            actionable_orders.ready_to_ship.count
          end

          def payments_to_collect
            actionable_orders.where(payment_state: 'balance_due').count
          end

          def open_returns
            Spree::ReturnAuthorization
              .where(state: 'authorized')
              .joins(:order)
              .where(Spree::Order.table_name => { store_id: store.id })
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

          def tracked_stock_items
            Spree::StockItem
              .for_store(store)
              .with_active_stock_location
              .where(Spree::Variant.table_name => { deleted_at: nil, track_inventory: true })
              .where(Spree::Product.table_name => { deleted_at: nil })
          end
        end
      end
    end
  end
end
