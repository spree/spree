object @order
extends "spree/api/orders/order"

if lookup_context.find_all("spree/api/orders/#{root_object.state}").present?
  extends "spree/api/orders/#{root_object.state}"
end

child :billing_address => :bill_address do
  extends "spree/api/addresses/show"
end

child :shipping_address => :ship_address do
  extends "spree/api/addresses/show"
end

child :line_items => :line_items do
  extends "spree/api/line_items/show"
end

child :payments => :payments do
  attributes :id, :amount, :state, :source_type

  child :payment_method => :payment_method do
    attributes :id, :name, :environment
  end

  child :source => :source do
    attributes *payment_source_attributes
  end
end

child :shipments => :shipments do
  extends "spree/api/shipments/small"
end

child :adjustments => :adjustments do
  extends "spree/api/adjustments/show"
end
