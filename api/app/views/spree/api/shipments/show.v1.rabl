object @shipment
attributes *shipment_attributes
node(:order_id) { |shipment| shipment.order.number }
node(:stock_location_name) { |shipment| shipment.stock_location.name }
child :shipping_rates => :shipping_rates do
  attributes  :id, :name, :cost, :selected, :shipping_method_id
  node(:display_cost) { |sr| sr.display_cost.to_s }
end
child :shipping_methods => :shipping_methods do
  attributes :id, :name
  child :zones => :zones do
    attributes :id, :name, :description
  end

  child :shipping_categories => :shipping_categories do
    attributes :id, :name
  end
end

child :manifest => :manifest do
  child :variant => :variant do
    extends "spree/api/variants/show"
  end
  node(:quantity) { |m| m.quantity }
  node(:states) { |m| m.states }
end
