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

    # Default-channel backfill for existing stores lives in
    # +rake spree:channels:create_defaults+ (data transformations don't belong
    # in migrations per Spree's guidelines).
  end
end
