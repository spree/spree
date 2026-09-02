# frozen_string_literal: true

namespace :spree do
  namespace :price_history do
    desc 'Seed price history from existing base prices (run once after migration)'
    task seed: :environment do
      count = 0
      Spree::Price.where(deleted_at: nil, price_list_id: nil).find_each do |price|
        next if price.amount.nil?
        next if Spree::PriceHistory.exists?(price_id: price.id)

        Spree::PriceHistory.create!(
          price: price,
          variant_id: price.variant_id,
          amount: price.amount,
          compare_at_amount: price.compare_at_amount,
          currency: price.currency,
          recorded_at: price.updated_at || Time.current
        )
        count += 1
      end

      puts "Seeded #{count} price history records"
    end

    # Retention is per store, because whether a shop records price history at
    # all is (`track_price_history`). Pruning globally on one number would
    # delete an EU store's Omnibus evidence on the schedule of its non-EU
    # sibling.
    desc 'Prune price history older than each store\'s retention period'
    task prune: :environment do
      total = 0

      Spree::Store.find_each do |store|
        retention_days = store.preferred_price_history_retention_days
        next if retention_days.blank?

        # `with_deleted` on both: a soft-deleted variant or product still has
        # price history, and a scope that skips it would match no store at all
        # — leaving those rows to accumulate past the retention window the
        # task exists to enforce.
        variant_ids = Spree::Variant.with_deleted.
                      joins(:product).merge(Spree::Product.with_deleted).
                      where(spree_products: { store_id: store.id }).
                      select(:id)

        deleted = Spree::PriceHistory.
                  where(variant_id: variant_ids).
                  where(recorded_at: ...retention_days.days.ago).
                  delete_all

        total += deleted
        puts "Store #{store.name}: pruned #{deleted} price history records older than #{retention_days} days"
      end

      puts "Pruned #{total} price history records"
    end
  end
end
