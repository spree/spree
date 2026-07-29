class RelaxOwnerNullConstraints < ActiveRecord::Migration[7.2]
  # Owner XOR: order_id becomes nullable where cart_id joined the pattern.
  def change
    change_column_null :spree_stock_reservations, :order_id, true
    change_column_null :spree_payment_sessions, :order_id, true
  end
end
