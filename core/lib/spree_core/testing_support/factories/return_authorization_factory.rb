Factory.define :return_authorization do |f|
  f.number "100"
  f.amount 100.00
  #f.order { Factory(:order) }
  f.order { Factory(:order_with_inventory_unit_shipped) }
  f.reason "no particular reason"
  f.state "received"
end
