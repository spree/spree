class AddStoreIdToSpreeCustomerReturns < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_customer_returns, :store_id)
      add_column :spree_customer_returns, :store_id, :bigint
      add_index :spree_customer_returns, :store_id
      Spree::CustomerReturn.reset_column_information
      default_store_id = Spree::Store.default.id
      Spree::CustomerReturn.find_each { |cr| cr.update_column(:store_id, cr.order&.store_id || default_store_id) }
    end
  end
end
