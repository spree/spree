Factory.define(:inventory_unit) do |record|
  record.variant { Factory(:variant) }
  record.order { Factory(:order) }
  record.state "pending"
  record.shipment { Factory(:shipment) }
  record.return_authorization { Fctory(:return_authorization) }
end
