class CreateSpreeProductSlugTranslationsForMobilityTableBackend < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_product_translations, :slug, :string
  end
end
