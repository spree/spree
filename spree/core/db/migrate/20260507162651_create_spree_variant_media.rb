class CreateSpreeVariantMedia < ActiveRecord::Migration[7.2]
  # `media_id` references spree_assets.id in 5.5 — the parent table renames to
  # spree_media in 6.0 (see 5.4-6.0-product-media-system.md Phase 3 of the 6.0
  # cleanup). Using `media_id` from the start saves a column rename in 6.0.
  #
  # Table name is `spree_variant_media` (not the Rails default `spree_variant_medias`)
  # since "media" reads as collective; the model overrides `self.table_name`.
  #
  # No per-variant `position` column — gallery order comes from the asset's
  # product-level position (Asset#position). Variant gallery resolution filters
  # product media down to the linked subset and inherits the product's order.
  def change
    create_table :spree_variant_media do |t|
      t.references :variant, null: false, index: false
      t.bigint :media_id, null: false
      t.timestamps
    end

    add_index :spree_variant_media, [:variant_id, :media_id], unique: true,
              name: 'idx_variant_media_unique'
    add_index :spree_variant_media, :media_id, name: 'idx_variant_media_media'
  end
end
