class MigrateCheckoutToOrders < ActiveRecord::Migration
  def up
    orders = select_all "SELECT * FROM orders"

    orders.each do |order|
      checkout = update_order(order)
      execute "DELETE FROM checkouts WHERE id = #{checkout['id']}" if checkout
    end
  end

  def down
  end

  private
    def update_order(order)
      checkout = select_one "SELECT * FROM checkouts WHERE order_id = #{order['id']}"

      if checkout
        execute "UPDATE orders SET email='#{checkout['email']}', bill_address_id = #{checkout['bill_address_id']}, ship_address_id = #{checkout['ship_address_id']} WHERE id = #{checkout['id']}"
      end
      checkout
    end
end
