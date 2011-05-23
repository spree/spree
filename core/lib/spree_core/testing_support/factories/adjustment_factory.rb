Factory.define :adjustment do  |f|
  f.order { Factory(:order) }
  f.amount "100.0"
  f.label 'Shipping'
  f.source { Factory(:shipment) }
  f.eligible true
end
