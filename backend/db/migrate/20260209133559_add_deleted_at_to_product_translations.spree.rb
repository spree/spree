# This migration comes from spree (originally 20221219123957)
class AddDeletedAtToProductTranslations < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_product_translations, :deleted_at, :datetime
    add_index :spree_product_translations, :deleted_at
  end
end
