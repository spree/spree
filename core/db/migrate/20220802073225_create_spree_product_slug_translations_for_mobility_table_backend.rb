class CreateSpreeProductSlugTranslationsForMobilityTableBackend < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_product_translations, :slug, :string
  end
end
