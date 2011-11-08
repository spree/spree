class MoveSpecialInstructionsToOrders < ActiveRecord::Migration
  def up
    add_column :orders, :special_instructions, :text
    execute "UPDATE orders SET special_instructions = (SELECT special_instructions FROM checkouts WHERE order_id = orders.id)"
  end

  def down
    remove_column :orders, :special_instructions, :text
  end
end
