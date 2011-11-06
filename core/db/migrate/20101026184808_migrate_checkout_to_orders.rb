class Checkout < ActiveRecord::Base; end;
class Order < ActiveRecord::Base; end;

class MigrateCheckoutToOrders < ActiveRecord::Migration
  def up
    Order.find_each do |order|
      checkout = update_order(order)
      checkout.destroy if checkout
    end
  end

  def update_order(order)
    checkout = Checkout.find_by_order_id(order.id)
    if checkout
      order.update_attributes_without_callbacks({
        :email => checkout.email,
        :bill_address_id => checkout.bill_address_id,
        :ship_address_id => checkout.ship_address_id
      })
    end
    checkout
  end

  def down
  end
end
