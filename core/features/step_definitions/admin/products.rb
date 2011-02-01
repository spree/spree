Then /^I should see listing products tabular attributes with name ascending$/ do
  output = tableish('table#listing_products tr', 'td,th')
  data = output[0]
  data[0].should == 'SKU'
  data[1].should match(/Name/)
  data[2].should == "Master Price"

  data = output[1]
  data[0].should == Product.limit(1).order('name desc').to_a.first.sku
end

Given /^a product exists with a sku of "a100"$/ do
  Factory(:product, :sku => 'a100')
end
