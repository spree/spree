# This migration comes from spree (originally 20251201172118)
class FixIndexesOnFriendlyIdSlugs < ActiveRecord::Migration[7.2]
  def change
    remove_index :friendly_id_slugs, [:slug, :sluggable_type, :locale]
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :locale], length: { slug: 140, sluggable_type: 50, locale: 5 }
    remove_index :friendly_id_slugs, [:slug, :sluggable_type, :scope, :locale]
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope, :locale], length: { slug: 70, sluggable_type: 50, scope: 70, locale: 5 }, unique: true, name: :index_friendly_id_slugs_unique
  end
end
