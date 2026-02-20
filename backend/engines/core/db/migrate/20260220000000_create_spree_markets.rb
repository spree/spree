class CreateSpreeMarkets < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_markets do |t|
      t.references :store, null: false, foreign_key: false, index: true
      t.string :name, null: false
      t.string :currency, null: false
      t.references :zone, null: false, foreign_key: false
      t.string :default_locale, null: false
      t.string :supported_locales
      t.boolean :tax_inclusive, null: false, default: false
      t.boolean :default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_markets, [:store_id, :name], unique: true, where: 'deleted_at IS NULL'
    add_index :spree_markets, [:store_id, :default], where: 'deleted_at IS NULL'
    add_index :spree_markets, [:store_id, :position]
    add_index :spree_markets, :deleted_at
  end
end
