class CreateSpreeStoreChannels < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_store_channels, if_not_exists: true do |t|
      t.belongs_to :store, index: true
      t.string :name, index: true

      t.timestamps
    end
  end
end
