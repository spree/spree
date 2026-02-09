# This migration comes from spree (originally 20220802070609)
class AddLocaleToFriendlyIdSlugs < ActiveRecord::Migration[6.1]
  def change
    add_column :friendly_id_slugs, :locale, :string, null: :false, after: :scope

    remove_index :friendly_id_slugs, [:slug, :sluggable_type]
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :locale], length: { slug: 140, sluggable_type: 50, locale: 2 }
    remove_index :friendly_id_slugs, [:slug, :sluggable_type, :scope]
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope, :locale], length: { slug: 70, sluggable_type: 50, scope: 70, locale: 2 }, unique: true, name: :index_friendly_id_slugs_unique
    add_index :friendly_id_slugs, :locale
  end
end
