class AddStoreIdToSpreeTaxonomies < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_taxonomies, :store_id)
      add_column :spree_taxonomies, :store_id, :bigint
      add_index :spree_taxonomies, :store_id
      add_index :spree_taxonomies, [:name, :store_id], unique: true
      Spree::Taxonomy.reset_column_information
      Spree::Taxonomy.update_all(store_id: Spree::Store.default.id)
    end
  end
end
