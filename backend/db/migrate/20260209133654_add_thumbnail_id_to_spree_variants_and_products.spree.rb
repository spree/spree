# This migration comes from spree (originally 20260131000000)
class AddThumbnailIdToSpreeVariantsAndProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_variants, :thumbnail_id, :bigint, if_not_exists: true
    add_column :spree_products, :thumbnail_id, :bigint, if_not_exists: true

    add_index :spree_variants, :thumbnail_id, if_not_exists: true
    add_index :spree_products, :thumbnail_id, if_not_exists: true
  end
end
