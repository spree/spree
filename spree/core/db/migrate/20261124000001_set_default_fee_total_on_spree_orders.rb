class SetDefaultFeeTotalOnSpreeOrders < ActiveRecord::Migration[8.1]
  # The column was added without a default, so an order nothing recalculated
  # since held no fee total while every other total held zero.
  def up
    change_column_default :spree_orders, :fee_total, from: nil, to: 0
    backfill
  end

  def down
    change_column_default :spree_orders, :fee_total, from: 0, to: nil
  end

  private

  # The sum of the order's fees, which is zero for an order with none.
  def backfill
    Spree::Order.unscoped.where(fee_total: nil).update_all(<<~SQL.squish)
      fee_total = (
        SELECT COALESCE(SUM(amount), 0) FROM #{Spree::Fee.table_name}
         WHERE #{Spree::Fee.table_name}.order_id = #{Spree::Order.table_name}.id
      )
    SQL
  end
end
