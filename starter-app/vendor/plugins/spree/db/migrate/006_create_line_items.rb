class CreateLineItems < ActiveRecord::Migration
  def self.up
	  create_table "line_items", :force => true do |t|
	    t.column "order_id",     :integer
	    t.column "product_id",   :integer
      t.column "variant_id",   :integer
	    t.column "quantity",     :integer, :null => false
	    t.column "price",        :decimal, :precision => 8, :scale => 2, :null => false
	    t.column "created_at",   :datetime
	    t.column "updated_at",   :datetime
	  end
  end

  def self.down
    drop_table "line_items"
  end
end