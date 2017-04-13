class ChangeIndexesOnFriendlyIdSlugs < ActiveRecord::Migration[5.0]
  def change
    # Updating indexes to reflect changes in friendly_id v5.2
    # See: https://github.com/norman/friendly_id/pull/694/commits/9f107f07ec9d2a58bda5a712b6e79a8d8013e0ab
    remove_index :friendly_id_slugs, [:slug, :sluggable_type]
    remove_index :friendly_id_slugs, [:slug, :sluggable_type, :scope]
    add_index :friendly_id_slugs, [:slug, :sluggable_type], length: { name: 100, slug: 20, sluggable_type: 20 }
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope], length: { name: 100, slug: 20, sluggable_type: 20, scope: 20 }, unique: true
  end
end
