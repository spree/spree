module Spree
  module MaintenanceTasks
    module Upgrade
      # 5.6 → 6.0: market is mandatory on orders in Spree 6, and orders placed
      # before markets existed carry NULLs. Each order takes its own store's
      # default market, so the walk is per order rather than one UPDATE per
      # store — that is what gives the run a cursor to resume from and a
      # progress bar to watch on a catalog-sized table.
      #
      # Orders whose store has no default market are counted and left alone;
      # there is nothing to assign, and failing the run would strand every
      # other store's orders behind them.
      class BackfillOrderMarkets < Spree::MaintenanceTask
        description 'maintenance_tasks.backfill_order_markets.description'
        supports_dry_run
        collection_batch_size 500

        def collection
          Spree::Order.unscoped.where(market_id: nil).order(:id)
        end

        def process(order)
          market_id = default_market_id_for(order.store_id)

          if market_id.nil?
            tally(:skipped_no_default_market)
            return
          end

          return tally(:would_update) if dry_run?

          order.update_columns(market_id: market_id, updated_at: Time.current)
          tally(:updated)
        end

        private

        # One lookup per store rather than per order: a backfill of this size
        # walks the same handful of stores over and over.
        def default_market_id_for(store_id)
          @default_market_ids ||= {}
          return @default_market_ids[store_id] if @default_market_ids.key?(store_id)

          @default_market_ids[store_id] = Spree::Store.find_by(id: store_id)&.default_market&.id
        end
      end
    end
  end
end
