Factory.define(:inventory_unit) do |record|
  record.variant { Factory(:variant) }
  record.order { Factory(:order) }
  record.state "sold"
  record.shipment { Factory(:shipment, :state => 'pending') }
  #record.return_authorization { Factory(:return_authorization) }
end
