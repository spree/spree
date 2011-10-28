Given /^count_on_hand is 10 for all products$/ do
  Spree::Product.update_all('count_on_hand=10')
end

Then /^I should see listing products tabular attributes with name ascending$/ do
  output = tableish('table#listing_products tr', 'td,th')
  data = output[0]
  data[0].should == 'SKU'
  data[1].should match(/Name/)
  data[2].should == 'Master Price'

  data = output[1]
  data[1].should == 'apache baseball cap'
end

Then /^I should see listing products tabular attributes with name descending$/ do
  output = tableish('table#listing_products tr', 'td,th')
  data = output[1]
  data[1].should == 'zomg shirt'
end

Then /^I should see listing products tabular attributes with custom result 1$/ do
  output = tableish('table#listing_products tr', 'td,th')
  output.size.should == 3
  data = output[1]
  data[1].should == 'apache baseball cap'
end

Then /^I should see listing products tabular attributes with custom result 2$/ do
  output = tableish('table#listing_products tr', 'td,th')
  output.size.should == 2
  data = output[1]
  data[1].should == 'apache baseball cap'
end

Given /^a product exists with a sku of "([^"]*)"$/ do |sku|
  Factory(:product, :sku => sku)
end

