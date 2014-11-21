class AddCurrencyToStoreCredits < ActiveRecord::Migration
  def change
    add_column :spree_store_credits, :currency, :string
  end
end
