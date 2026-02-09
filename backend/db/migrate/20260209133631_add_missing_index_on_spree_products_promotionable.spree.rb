# This migration comes from spree (originally 20250911205659)
class AddMissingIndexOnSpreeProductsPromotionable < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_products, :promotionable, if_not_exists: true
  end
end
