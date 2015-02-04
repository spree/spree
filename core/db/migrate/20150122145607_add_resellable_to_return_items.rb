class AddResellableToReturnItems < ActiveRecord::Migration
  def change
    add_column :spree_return_items, :resellable, :boolean, default: true, null: false
  end
end
