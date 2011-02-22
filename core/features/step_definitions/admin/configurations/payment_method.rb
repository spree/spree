Then /^I should see listing payment methods tabular attributes$/ do
  output = tableish('table#listing_payment_methods tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Provider"
  data[2].should == "Environment"
  data[3].should == "Display"
  data[4].should == "Active"

  data = output[1]
  data[0].should == 'Check'
  data[1].should == 'PaymentMethod::Check'
end
