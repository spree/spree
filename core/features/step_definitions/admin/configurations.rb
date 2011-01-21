Then /^I should see listing states tabular attributes$/ do
  output = tableish('table#listing_states tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Abbreviation"

  data = output[1]
  data[0].should == State.limit(1).order('name asc').to_a.first.name
  data[1].should == State.limit(1).order('name asc').to_a.first.abbr
end

Then /^I should see listing zones tabular attributes$/ do
  output = tableish('table#listing_zones tr', 'td,th')
  data = output[0]
  data[0].should match(/Name/)
  data[1].should == "Description"

  data = output[1]
  data[0].should == Zone.limit(1).order('name asc').to_a.first.name
  data[1].should == Zone.limit(1).order('name asc').to_a.first.description
end

Then /^I should see listing tax categories tabular attributes$/ do
  output = tableish('table#listing_tax_categories tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Description"
  data[2].should == "Default"

  data = output[1]
  data[0].should == TaxCategory.limit(1).order('name asc').to_a.first.name
end
