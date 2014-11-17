class AddDefaultValueToStoreCreditsAmount < ActiveRecord::Migration
  def up
    change_column :spree_store_credits, :amount, :decimal, precision: 8, scale: 2, default: 0.0, null: false
  end

  def down
    change_column :spree_store_credits, :amount, :decimal, precision: 8, scale: 2, null: false
  end
end
