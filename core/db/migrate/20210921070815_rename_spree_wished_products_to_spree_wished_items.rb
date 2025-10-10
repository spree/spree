class RenameSpreeWishedProductsToSpreeWishedItems < ActiveRecord::Migration[5.2]
  def change
    rename_table :spree_wished_products, :spree_wished_items
  end
end
