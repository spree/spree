class AddDeletedAtToProductTranslations < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_product_translations, :deleted_at, :datetime
    add_index :spree_product_translations, :deleted_at
  end
end
