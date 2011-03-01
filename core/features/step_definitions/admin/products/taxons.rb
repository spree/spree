Then /^I should see (.*) tabular records with selector "(.*)"$/ do |count, selector|
  output = tableish("#{selector} tr", "td,th")
  output.size.should == count.to_i
end

Given /^custom taxons exist$/ do
  taxon = Factory(:taxon, :name => 'Brands')
  taxon2 = Factory(:taxon, :taxonomy => taxon.taxonomy, :parent_id => taxon.id, :name => 'Apache')
end

Then /^verify admin taxons listing$/ do
  output = tableish('#search_hits table.index tr', 'td,th')
  output.size.should == 4
  output[0].should == %w(Name Path Action)
  output[1].should == ['Brand','','Select']
  output[2].should == ['Brands','','Select']
  output[3].should == %w(Apache Brands Select)
end

