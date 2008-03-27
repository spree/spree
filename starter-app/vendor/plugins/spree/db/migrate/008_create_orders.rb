class CreateOrders < ActiveRecord::Migration
  def self.up
	  create_table :orders, :force => true do |t|
      t.integer :user_id
      t.string :number, :limit => 15
      t.integer :status
      t.integer :ship_method
      t.decimal :ship_amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal :tax_amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal :item_total, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.decimal :total, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string :ip_address
      t.text :special_instructions
      t.integer :ship_address_id
      t.integer :bill_address_id
      t.timestamps
    end
  end

  def self.down
    drop_table :orders
  end
end