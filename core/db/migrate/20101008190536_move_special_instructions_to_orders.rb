class MoveSpecialInstructionsToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :special_instructions, :text

    ActiveRecord::Base.connection.execute("update orders set special_instructions = (select special_instructions from checkouts where order_id = orders.id)")
  end

  def self.down
    remove_column :orders, :special_instructions, :text
  end
end
