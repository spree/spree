class AddMoreNeededKeysItemsAndConf < ActiveRecord::Migration
  def self.up
    add_index :line_items, [:order_id]
    add_index :line_items, [:variant_id]

    add_index :configurations, [:name, :type]
    add_index :creditcards, [:order_id]
    add_index :orders, [:checkout_complete]
  end

  def self.down
    remove_index :orders, :column => [:checkout_complete]
    remove_index :creditcards, :column => [:order_id]
    remove_index :configurations, :column => [:name, :type]

    remove_index :line_items, :column => [:variant_id]
    remove_index :line_items, :column => [:order_id]
  end
end