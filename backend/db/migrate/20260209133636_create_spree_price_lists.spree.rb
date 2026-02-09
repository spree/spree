# This migration comes from spree (originally 20251110120000)
class CreateSpreePriceLists < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_price_lists do |t|
      t.belongs_to :store, null: false, foreign_key: false, index: true
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: 'draft'
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :match_policy, null: false, default: 'all'
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_price_lists, :status
    add_index :spree_price_lists, :position
    add_index :spree_price_lists, [:starts_at, :ends_at]
    add_index :spree_price_lists, :deleted_at
    add_index :spree_price_lists, [:store_id, :status, :position]
  end
end
