Factory.define(:shipment) do |record|
  # associations: 
  record.association(:address, :factory => :address)
  record.association(:order, :factory => :order)
  record.association(:shipping_method, :factory => :shipping_method)
end