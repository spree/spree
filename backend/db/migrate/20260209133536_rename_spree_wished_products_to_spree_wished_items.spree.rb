# This migration comes from spree (originally 20210921070815)
class RenameSpreeWishedProductsToSpreeWishedItems < ActiveRecord::Migration[5.2]
  def change
    rename_table :spree_wished_products, :spree_wished_items
  end
end
