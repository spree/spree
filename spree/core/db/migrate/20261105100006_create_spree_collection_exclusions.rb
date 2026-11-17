class CreateSpreeCollectionExclusions < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_collection_exclusions do |t|
      t.references :collection, null: false, index: false
      t.references :product, null: false
      t.timestamps
    end

    add_index :spree_collection_exclusions, %i[collection_id product_id], unique: true,
                                                                          name: 'index_spree_collection_exclusions_on_collection_and_product'
  end
end
