class Order < ActiveRecord::Base; end;

class RemoveShippedState < ActiveRecord::Migration
  def up
    Order.where(:state => 'shipped').each do |order|
      order.update_attribute_without_callbacks("state", "complete")
      order.shipments.each do |shipment|
        shipment.state = 'shipped'
        shipment.save
      end
    end
  end

  def down
  end
end
