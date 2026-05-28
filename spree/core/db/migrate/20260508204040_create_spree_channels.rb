class CreateSpreeChannels < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_channels do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, null: false
      t.text :preferences
      t.timestamps
    end

    add_index :spree_channels, %i[store_id code], unique: true

    # backfill / create default channel for existing stores
    Spree::Store.find_each do |store|
      store.send(:ensure_default_market)
    end
  end
end
