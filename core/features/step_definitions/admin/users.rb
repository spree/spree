Then /^I should see listing users tabular attributes$/ do
  output = tableish('table#listing_users tr', 'td,th')
  data = output[0]
  data[0].should match(/User/)

  data = output[1]
  #data[0].should == Product.limit(1).order('name desc').to_a.first.sku
end

