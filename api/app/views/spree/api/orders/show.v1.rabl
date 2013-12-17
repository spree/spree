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
  attributes :id, :amount, :state, :payment_method_id
  child :payment_method => :payment_method do
    attributes :id, :name, :environment
  end
end

child :shipments => :shipments do
  extends "spree/api/shipments/show"
end

child :adjustments => :adjustments do
  extends "spree/api/adjustments/show"
end

child :credit_cards => :credit_cards do
  extends "spree/api/credit_cards/show"
end