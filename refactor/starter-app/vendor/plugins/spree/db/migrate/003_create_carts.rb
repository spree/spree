class CreateCarts < ActiveRecord::Migration
  def self.up
	  create_table "carts", :force => true do |t|
	    t.column "created_at", :datetime
	    t.column "updated_at", :datetime
	  end
  end

  def self.down
    drop_table "carts"
  end
end