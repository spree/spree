object @order
attributes *order_attributes
node :state_info do |order|
  extends "spree/api/v1/orders/#{order.state}"
end
