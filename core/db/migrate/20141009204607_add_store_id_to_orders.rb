class AddStoreIdToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :store_id, :integer
    if Spree::Store.default.persisted?
      Spree::Order.where(store_id: nil).update_all(store_id: Spree::Store.default.id)
    end
  end
end
