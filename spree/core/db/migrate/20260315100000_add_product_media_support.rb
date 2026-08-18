class AddProductMediaSupport < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_assets, :media_type, :string
    add_column :spree_assets, :focal_point_x, :decimal, precision: 5, scale: 4
    add_column :spree_assets, :focal_point_y, :decimal, precision: 5, scale: 4
    add_column :spree_assets, :external_video_url, :string

    add_index :spree_assets, :media_type

    rename_column :spree_variants, :image_count, :media_count
    rename_column :spree_products, :total_image_count, :media_count
    rename_column :spree_variants, :thumbnail_id, :primary_media_id
    rename_column :spree_products, :thumbnail_id, :primary_media_id

    reversible do |dir|
      dir.up do
        # Raw SQL against this migration's own table name — Spree::Asset became
        # Spree::Media on a later migration, so reaching through the model here
        # would look for a table that does not exist yet.
        execute "UPDATE spree_assets SET media_type = 'image' WHERE media_type IS NULL"
      end
    end
  end
end
