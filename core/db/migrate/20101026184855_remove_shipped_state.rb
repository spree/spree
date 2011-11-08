class RemoveShippedState < ActiveRecord::Migration
  def up
    execute "UPDATE orders SET state = 'complete' WHERE state = 'shipped'"
    shipments = select_all "SELECT shipments.id FROM shipments WHERE order_id IN (SELECT orders.id FROM orders WHERE orders.state = 'shipped')"
    shipments.each do |shipment|
      execute "UPDATE shipments SET state='shipped' WHERE id = #{shipment[:id]}"
    end
  end

  def down
  end
end
