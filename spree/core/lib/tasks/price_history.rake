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

    desc 'Prune price history older than retention period'
    task prune: :environment do
      retention_days = Spree::Config[:price_history_retention_days] || 30
      deleted = Spree::PriceHistory
                .where('recorded_at < ?', retention_days.days.ago)
                .delete_all

      puts "Pruned #{deleted} price history records older than #{retention_days} days"
    end
  end
end
