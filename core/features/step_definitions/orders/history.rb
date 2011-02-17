Given /^the order is finalized$/ do
  order = Order.last
  order.finalize!
end

Then /^I should see order history tabular attributes$/ do
  output = tableish('table#index tr', 'td,th')
  data = output[0]
  data[0].should == 'RMA Number'
  data[1].should == 'Status'
  data[2].should == 'Amount'
  data[3].should == 'Date/Time'

  data = output[1]
  data[0].should == 'Order'
  data[1].should == 'cart'
  data[2].should == 'complete'
end
