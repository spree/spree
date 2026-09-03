class RenamePromoTotalToDiscountTotal < ActiveRecord::Migration[8.1]
  # The last two tables still carrying promo_total; spree_orders moved in
  # 20260729120001 and spree_carts was born with the new name, which left
  # LineItem and Fulfillment aliasing in the opposite direction to Order.
  def change
    rename_column :spree_line_items, :promo_total, :discount_total
    rename_column :spree_fulfillments, :promo_total, :discount_total
  end
end
