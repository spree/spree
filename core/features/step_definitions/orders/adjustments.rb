When /^I follow "New Adjustment" custom$/ do
  page.first('#content .toolbar .actions li a').click
end

Given /^an adjustment exists for order R100$/ do
  order = Order.find_by_number('R100')
  Factory(:adjustment, :order => order)
end

Then /^I should see tabular attributes for adjustments index$/ do
  output = tableish('table.index tr', 'td,th')
  data = output[0]
  data[0].should == 'Date/Time'
  data[1].should == 'Description'
  data[2].should == 'Amount'

  data = output[1]
  data[1].should == 'Shipping'
  data[2].should == '$100.00'
end
