Given /^count_on_hand is 10 for all products$/ do
  Product.update_all("count_on_hand=10")
end

Then /^I should see listing products tabular attributes with name ascending$/ do
  output = tableish('table#listing_products tr', 'td,th')
  data = output[0]
  data[0].should == 'SKU'
  data[1].should match(/Name/)
  data[2].should == "Master Price"

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

Given /^a product exists with a sku of "a100"$/ do
  Factory(:product, :sku => 'a100')
end
When /^I attach file "(.*)" to "(.*)"$/ do |file_name, field|
  absolute_path = File.expand_path(Rails.root.join('..', '..', 'features', 'step_definitions', file_name))
  When %Q{I attach the file "#{absolute_path}" to "#{field}"}
end

Then /^I wait for (.*) seconds?$/ do |seconds|
  sleep seconds.to_i
end

Then /^verify admin taxons listing$/ do
  output = tableish('#search_hits table.index tr', 'td,th')
  output.size.should == 4
  output[0].should == %w(Name Path Action)
  output[1].should == ['Brand','','Select']
  output[2].should == ['Brands','','Select']
  output[3].should == %w(Apache Brands Select)
end

Given /^custom taxons exist$/ do
  taxon = Factory(:taxon, :name => 'Brands')
  taxon2 = Factory(:taxon, :taxonomy => taxon.taxonomy, :parent_id => taxon.id, :name => 'Apache')
end
