Then /^I should see listing option types tabular attributes$/ do
  output = tableish('table#listing_option_types tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == 'Presentation'

  data = output[1]
  data[0].should == Spree::OptionType.limit(1).order('position ASC').to_a.first.name
end
