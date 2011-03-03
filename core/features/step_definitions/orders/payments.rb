Given /^custom payment associated with order R100$/ do
  order = Order.find_by_number('R100')
  Factory(:payment, :order => order, :amount => order.outstanding_balance)
end

Given /^a completed order$/ do
  address = Factory(:address)

  order = Order.find_by_number('R100')
  order.update_attributes(:bill_address_id => address.id, :ship_address_id => address.id)

  payment = Factory(:payment, :order_id => order.id, :amount => 30.00)

  product = Factory(:product, :name => 'spree t-shirt')

  shipment = Factory.build(:shipment, :order_id => order.id)

  inventory_unit = Factory.build(:inventory_unit, :variant_id => product.master.id,
                                            :order_id => order.id)

  shipment.inventory_units << inventory_unit

  shipment.save!

  line_item = Factory(:line_item, :order_id => order.id,
                                  :variant_id => product.master.id,
                                  :quantity => 2,
                                  :price => 10)

end

