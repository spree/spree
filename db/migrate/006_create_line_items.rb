class CreateLineItems < ActiveRecord::Migration
  def self.up
	  create_table "line_items", :force => true do |t|
	    t.integer :order_id
	    t.integer :variant_id
	    t.integer :quantity, :null => false
	    t.decimal :price, :precision => 8, :scale => 2, :null => false
	    t.timestamps
	  end
  end

  def self.down
    drop_table "line_items"
  end
end