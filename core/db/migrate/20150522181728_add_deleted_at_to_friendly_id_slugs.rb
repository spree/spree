class AddDeletedAtToFriendlyIdSlugs < ActiveRecord::Migration[4.2]
  def change
    add_column :friendly_id_slugs, :deleted_at, :datetime
    add_index :friendly_id_slugs, :deleted_at
  end
end
