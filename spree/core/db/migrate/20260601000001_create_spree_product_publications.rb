class CreateSpreeProductPublications < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_product_publications, if_not_exists: true do |t|
      t.references :product, null: false
      t.references :channel, null: false
      t.datetime :published_at
      t.datetime :unpublished_at
      t.timestamps
    end

    add_index :spree_product_publications, %i[product_id channel_id], unique: true,
              name: 'index_spree_product_publications_on_product_and_channel', if_not_exists: true
  end
end
