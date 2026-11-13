class CreateSpreeCollectionPublications < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_collection_publications do |t|
      t.references :collection, null: false
      t.references :channel, null: false
      t.datetime :published_at
      t.datetime :unpublished_at
      t.timestamps
    end

    add_index :spree_collection_publications, %i[collection_id channel_id], unique: true,
                                                                            name: 'index_spree_collection_publications_on_collection_and_channel'
  end
end
