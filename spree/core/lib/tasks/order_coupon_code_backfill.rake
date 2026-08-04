# frozen_string_literal: true

# 5.6 → 6.0: spree_orders gained a coupon_code column (parity with
# spree_carts). Historical placed orders applied coupons through the
# promotion join tables only — backfill the column from those records so
# admin filtering and the serializer answer consistently for old orders.
namespace :spree do
  desc 'Backfill spree_orders.coupon_code from applied promotion/coupon-code records'
  task backfill_order_coupon_codes: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
    updated = 0

    scope = Spree::Order.unscoped.where(coupon_code: nil).where.not(completed_at: nil)

    scope.in_batches(of: batch_size) do |batch|
      batch.each do |order|
        code = Spree::CouponCode.where(order_id: order.id).order(:id).limit(1).pick(:code) ||
               Spree::Promotion.joins(:order_promotions).
                 where(Spree::OrderPromotion.table_name => { order_id: order.id }).
                 where.not(code: [nil, '']).order(:id).limit(1).pick(:code)
        next if code.blank?

        order.update_columns(coupon_code: code.downcase)
        updated += 1
      end
      print '.'
    end

    puts
    puts "backfill_order_coupon_codes done. updated: #{updated}"
  end
end
