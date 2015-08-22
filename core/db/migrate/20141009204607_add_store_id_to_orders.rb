class AddStoreIdToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :store_id, :integer
    defaults = Spree::Store.where(default: true)
    if defaults.one?
      Spree::Order.update_all(store_id: defaults.first!)
    end
  end
end
