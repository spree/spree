class AddUserTotalAmountToStoreCreditEvents < ActiveRecord::Migration
  def change
    add_column :spree_store_credit_events, :user_total_amount, :decimal, precision: 8, scale: 2, default: 0.0, null: false
  end
end
