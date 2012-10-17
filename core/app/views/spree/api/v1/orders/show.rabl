object @order
attributes *order_attributes

if lookup_context.find_all("spree/api/v1/orders/#{@order.state}").present?
  extends "spree/api/v1/orders/#{@order.state}"
end

child :billing_address => :bill_address do
  extends "spree/api/v1/addresses/show"
end

child :shipping_address => :ship_address do
  extends "spree/api/v1/addresses/show"
end

child :line_items => :line_items do
  extends "spree/api/v1/line_items/show"
end

child :payments => :payments do
  attributes :id, :amount, :state, :payment_method_id
  child :payment_method => :payment_method do
    attributes :id, :name, :environment
  end
end

child :shipments => :shipments do
  extends "spree/api/v1/shipments/show"
end
