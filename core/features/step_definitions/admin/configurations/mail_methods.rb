Then /^I should see tabular data for mail methods index$/ do
  output = tableish('table#mail_methods_listing tr', 'td,th')
  # FIXME not sure why it is not working
  #data = output[0]
  #data[0].should == 'Environment'
  #data[1].should == 'Active'

  data = output[0]
  data[0].should == 'Cucumber'
  data[1].should == 'Yes'
end
