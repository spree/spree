object @order
attributes *order_attributes
extends "spree/api/v1/orders/#{@order.state}"

child :billing_address => :bill_address do
  extends "spree/api/v1/orders/address"
end

child :shipping_address => :ship_address do
  extends "spree/api/v1/orders/address"
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
  attributes :id, :special_instructions, :shipping_method_id,
             :tracking, :state
  child :shipping_method => :shipping_method do
    attributes :name, :zone_id, :shipping_category_id
  end
end