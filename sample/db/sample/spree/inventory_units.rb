# create the inventory units associated with the line item (we need to do this after the fixture b/c quantity is random)
Spree::LineItem.all.each do |li|
  li.quantity.times { li.order.inventory_units.create({:variant => li.variant, :state => 'sold', :shipment => li.order.shipment}, :without_protection => true) }
end
