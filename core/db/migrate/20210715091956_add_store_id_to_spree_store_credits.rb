class AddStoreIdToSpreeStoreCredits < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_store_credits, :store_id)
      add_column :spree_store_credits, :store_id, :bigint
      add_index :spree_store_credits, :store_id
      Spree::StoreCredit.reset_column_information
      Spree::StoreCredit.update_all(store_id: Spree::Store.default.id)
    end
  end
end
