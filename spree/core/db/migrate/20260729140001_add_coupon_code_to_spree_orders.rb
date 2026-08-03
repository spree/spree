class AddCouponCodeToSpreeOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_orders, :coupon_code, :string
    add_index :spree_orders, :coupon_code
  end
end
