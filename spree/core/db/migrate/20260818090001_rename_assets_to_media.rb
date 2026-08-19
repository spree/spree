class RenameAssetsToMedia < ActiveRecord::Migration[8.1]
  # The API, the prefixed id (`media_...`) and the join table have all said
  # "media" since 5.4/5.5. This brings the table and model in line.
  #
  # `spree_variant_media.media_id` already points here under the right name, so
  # no foreign-key column changes.
  def change
    rename_table :spree_assets, :spree_media
  end
end
