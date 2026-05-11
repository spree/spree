class BackfillStatusOnSpreeOrders < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE spree_orders SET status = 'placed'
       WHERE status IS NULL AND state IN ('complete', 'resumed', 'returned')
    SQL

    execute <<~SQL.squish
      UPDATE spree_orders SET status = 'canceled'
       WHERE status IS NULL AND state = 'canceled'
    SQL

    execute "UPDATE spree_orders SET status = 'draft' WHERE status IS NULL"

    change_column_default :spree_orders, :status, 'draft'
    change_column_null    :spree_orders, :status, false
  end

  def down
    change_column_null    :spree_orders, :status, true
    change_column_default :spree_orders, :status, nil
  end
end
