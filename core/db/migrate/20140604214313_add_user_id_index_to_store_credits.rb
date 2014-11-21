class AddUserIdIndexToStoreCredits < ActiveRecord::Migration
  def change
    add_index :spree_store_credits, :user_id
  end
end
