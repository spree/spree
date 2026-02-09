# This migration comes from spree (originally 20260120120000)
class AddImageCountToSpreeVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_variants, :image_count, :integer, default: 0, null: false, if_not_exists: true
    add_column :spree_products, :total_image_count, :integer, default: 0, null: false, if_not_exists: true

    add_index :spree_variants, :image_count, if_not_exists: true
    add_index :spree_products, :total_image_count, if_not_exists: true
  end
end
