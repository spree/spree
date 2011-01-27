Factory.define :shipment do |f|
  f.order { Factory(:order) }
  f.shipping_method { Factory(:shipping_method) }
  f.tracking 'U10000'
  f.number "100"
  f.cost 100.00
  f.address { Factory(:address) }
  f.state "pending"
end
