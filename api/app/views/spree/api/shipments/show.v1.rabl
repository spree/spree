object @shipment
attributes *shipment_attributes
node(:order_id) { |shipment| shipment.order.number }
node(:stock_location_name) { |shipment| shipment.stock_location.name }
child :shipping_rates => :shipping_rates do
  attributes  :id, :cost, :selected, :shipment_id, :shipping_method_id
end
child :shipping_method => :shipping_method do
  attributes :name, :zone_id, :shipping_category_id
end

child :inventory_units => :inventory_units do
  attribute *inventory_unit_attributes
end
