Then /^I should see listing option types tabular attributes$/ do
  output = tableish('table#listing_option_types tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Presentation"

  data = output[1]
  data[0].should == OptionType.limit(1).order('position asc').to_a.first.name
end
