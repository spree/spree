class DeleteInProgressOrders < ActiveRecord::Migration
  def up
    execute("DELETE FROM orders WHERE orders.state = 'in_progress'")
    delete_orphans('adjustments')
    delete_orphans('checkouts')
    delete_orphans('shipments')
    delete_orphans('payments')
    delete_orphans('line_items')
    delete_orphans('inventory_units')
  end

  def down
  end

  private
    def delete_orphans(table_name)
      execute "DELETE FROM #{table_name} WHERE order_id NOT IN (SELECT id FROM orders)"
    end
end
