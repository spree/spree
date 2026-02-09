# This migration comes from spree (originally 20220802073225)
class CreateSpreeProductSlugTranslationsForMobilityTableBackend < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_product_translations, :slug, :string
  end
end
