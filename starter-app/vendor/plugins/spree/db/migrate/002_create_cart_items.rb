class CreateCartItems < ActiveRecord::Migration
  def self.up
	  create_table "cart_items", :force => true do |t|
	    t.column "cart_id",      :integer, :null => false
      t.column "variant_id",   :integer, :null => false
	    t.column "quantity",     :integer, :null => false
	  end
  end

  def self.down
    drop_table "cart_items"
  end
end