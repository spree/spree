Then /^I should see listing orders tabular attributes with created_at descending$/ do
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
  data[0].should == Order.limit(1).order('created_at desc').to_a.first.created_at.strftime('%Y-%m-%d')
end

Then /^I should see listing orders tabular attributes with created_at ascending$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[0].should == Order.limit(1).order('created_at asc').to_a.first.created_at.strftime('%Y-%m-%d')
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

Then /^I should see listing orders tabular attributes with search result 1$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[1].should == 'R100'
  output.size.should == 2
end

Then /^I should see listing orders tabular attributes with search result 2$/ do
  output = tableish('table#listing_orders tr', 'td,th')
  data = output[1]
  data[1].should == 'R100'
  output.size.should == 2
end
