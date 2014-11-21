class AddAmountAuthorizedToStoreCredits < ActiveRecord::Migration
  def change
    add_column :spree_store_credits, :amount_authorized, :decimal, precision: 8, scale: 2, default: 0.0, null: false
  end
end
