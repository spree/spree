class CreateSpreePriceLists < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_price_lists do |t|
      t.string :name, null: false
      t.text :description
      t.integer :priority, null: false, default: 0
      t.string :status, null: false, default: 'active'
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :match_policy, null: false, default: 'all'
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_price_lists, :status
    add_index :spree_price_lists, :priority
    add_index :spree_price_lists, [:starts_at, :ends_at]
    add_index :spree_price_lists, :deleted_at
  end
end
