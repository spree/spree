# This migration comes from spree (originally 20251110120001)
class CreateSpreePriceRules < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_price_rules do |t|
      t.belongs_to :price_list, null: false, foreign_key: false, index: true
      t.string :type, null: false
      t.text :preferences
      t.timestamps
    end

    add_index :spree_price_rules, [:price_list_id, :type]
    add_index :spree_price_rules, :type
  end
end
