class AddUniquenessConstraintToProductTranslations < ActiveRecord::Migration[7.0]
  def change
    add_index :spree_product_translations, [:locale, :slug], unique: true, name: 'unique_slug_per_locale'
  end
end
