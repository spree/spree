# This migration comes from spree (originally 20221229132350)
class CreateSpreeDataFeedSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_data_feed_settings do |t|
      t.references :spree_store

      t.string :name
      t.string :provider
      t.string :uuid, unique: true
      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end
