Then /^I should see listing products tabular attributes with name ascending$/ do
  output = tableish('table#listing_products tr', 'td,th')
  data = output[0]
  data[0].should == 'SKU'
  data[1].should match(/Name/)
  data[2].should == "Master Price"

  data = output[1]
  data[0].should == Product.limit(1).order('name desc').to_a.first.sku
end

Then /^I should see listing orders tabular attributes with completed_at descending$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[0]
  data[0].should match(/Order Date/)
  data[1].should == "Order"
  data[2].should == "Status"
  data[3].should == "Payment State"
  data[4].should == "Shipment State"
  data[5].should == "Customer"
  data[6].should == "Total"

  data = output[1]
  data[0].should == Order.limit(1).order('completed_at desc').to_a.first.completed_at.strftime('%Y-%m-%d')
end

Then /^I should see listing orders tabular attributes with completed_at ascending$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[0].should == Order.limit(1).order('completed_at asc').to_a.first.completed_at.strftime('%Y-%m-%d')
end

Then /^I should see listing orders tabular attributes with order number ascending$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[1].should == Order.limit(1).order('number asc').to_a.first.number
end

Then /^I should see listing orders tabular attributes with order number descending$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[1].should == Order.limit(1).order('number desc').to_a.first.number
end
