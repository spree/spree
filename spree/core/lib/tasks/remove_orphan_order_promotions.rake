# frozen_string_literal: true

# Deleting a promotion used to leave OrderPromotion rows on open carts pointing
# at a promotion that no longer exists, which broke loading those carts.
namespace :spree do
  desc 'Remove order promotions whose promotion no longer exists and recalculate the affected carts'
  task remove_orphan_order_promotions: :environment do
    orphans = Spree::OrderPromotion.where.not(promotion_id: Spree::Promotion.unscoped.select(:id))
    removed = 0

    orphans.find_each do |order_promotion|
      owner = order_promotion.owner
      order_promotion.destroy
      owner&.recalculate_totals! if owner.is_a?(Spree::Cart)
      removed += 1
    end

    puts "remove_orphan_order_promotions done. removed: #{removed}"
  end
end
