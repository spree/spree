class AddVersionUuidToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :version_uuid, :uuid
  end
end
