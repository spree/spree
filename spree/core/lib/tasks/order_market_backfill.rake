# frozen_string_literal: true

# 5.6 → 6.0: market is mandatory on orders in Spree 6. Orders created before
# markets existed carry NULLs — backfill from the store's default market so
# the 6.1 NOT NULL constraint can land. (channel_id has no equivalent task
# here: the 5.4→5.5 manifest's spree:channels:backfill_order_channel_ids
# already covers it on every upgrade path.)
namespace :spree do
  desc 'Backfill missing market on orders from the store default market'
  task backfill_order_markets: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i

    Spree::Store.all.find_each do |store|
      market_id = store.default_market&.id

      if market_id
        count = Spree::Order.unscoped.where(store_id: store.id, market_id: nil).
          in_batches(of: batch_size).update_all(market_id: market_id)
        puts "store #{store.code}: #{count} orders assigned market #{market_id}" if count.positive?
      else
        puts "store #{store.code}: no default market — orders left as-is"
      end
    end

    puts 'backfill_order_markets done. The NOT NULL constraint lands in 6.1.'
  end
end
