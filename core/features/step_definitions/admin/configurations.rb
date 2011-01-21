Then /^I should see listing tax categories tabular attributes$/ do
  output = tableish('table#listing_tax_categories tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Description"
  data[2].should == "Default"

  data = output[1]
  data[0].should == TaxCategory.limit(1).order('name asc').to_a.first.name
end
