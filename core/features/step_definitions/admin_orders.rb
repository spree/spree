Given /^2 custom orders$/ do
  Factory(:order, :completed_at => Time.now)
  Factory(:order, :completed_at => 1.year.ago)
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
  data = output[0]
  data[0].should match(/Order Date/)
  data[1].should == "Order"
  data[2].should == "Status"
  data[3].should == "Payment State"
  data[4].should == "Shipment State"
  data[5].should == "Customer"
  data[6].should == "Total"

  data = output[1]
  data[0].should == Order.limit(1).order('completed_at asc').to_a.first.completed_at.strftime('%Y-%m-%d')
end
