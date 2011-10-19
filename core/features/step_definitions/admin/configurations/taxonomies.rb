Then /^I should see tabular data for taxonomies list$/ do
  output = tableish('table#listing_taxonomies tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'

  data = output[1]
  data[0].should == Spree::Taxonomy.limit(1).order('name ASC').to_a.first.name
end
