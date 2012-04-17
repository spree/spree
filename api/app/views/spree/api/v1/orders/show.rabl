object @order
attributes *order_attributes
extends "spree/api/v1/orders/#{@order.state}"

child :billing_address => :billing_address do
  extends "spree/api/v1/orders/address"
end

child :shipping_address => :shipping_address do
  extends "spree/api/v1/orders/address"
end

child :line_items => :line_items do
  extends "spree/api/v1/line_items/show"
end