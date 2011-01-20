Then /^I should see listing product groups tabular attributes$/ do
  output = tableish('table#listing_product_groups tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "URL"
  data[2].should == "Product scopes"
  data[3].should == "Product count"
  data[4].should == "Action"

  data = output[1]
  data[0].should == ProductGroup.limit(1).order('name desc').to_a.first.name
end
