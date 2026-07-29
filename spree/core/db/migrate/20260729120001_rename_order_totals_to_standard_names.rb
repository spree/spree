class RenameOrderTotalsToStandardNames < ActiveRecord::Migration[7.2]
  def change
    rename_column :spree_orders, :promo_total, :discount_total
    rename_column :spree_orders, :item_count, :total_quantity
  end
end
