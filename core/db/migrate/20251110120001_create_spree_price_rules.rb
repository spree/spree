class CreateSpreePriceRules < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_price_rules do |t|
      t.references :price_list, null: false
      t.string :type, null: false
      t.integer :priority, null: false, default: 0
      t.text :preferences
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_price_rules, [:price_list_id, :type]
    add_index :spree_price_rules, :type
    add_index :spree_price_rules, :priority
    add_index :spree_price_rules, :deleted_at
  end
end
