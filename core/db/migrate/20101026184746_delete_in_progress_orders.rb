# legacy table support
class Order < ActiveRecord::Base; end;

class DeleteInProgressOrders < ActiveRecord::Migration
  def up
    Order.delete_all(:state => 'in_progress')
    delete_orphans('adjustments')
    delete_orphans('checkouts')
    delete_orphans('shipments')
    delete_orphans('payments')
    delete_orphans('line_items')
    delete_orphans('inventory_units')
  end

  def self.delete_orphans(table_name)
    execute("DELETE FROM #{table_name} WHERE order_id NOT IN (SELECT id FROM orders)")
  end

  def down
  end
end
