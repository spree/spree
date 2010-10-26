class DeleteInProgressOrders < ActiveRecord::Migration
  def self.up
    Order.delete_all(:state=>'in_progress')
    delete_orphans('adjustments')
    delete_orphans('checkouts')
    delete_orphans('shipments')
    delete_orphans('payments')
    delete_orphans('line_items')
    delete_orphans('inventory_units')
  end

  def self.delete_orphans(table_name)
    execute("delete from #{table_name} where order_id not in (select id from orders)")
  end

  def self.down
  end
end