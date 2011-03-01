Given /^the custom taxons and custom products exist$/ do

  taxonomy = Taxonomy.find_by_name('Categories')
  root = taxonomy.root
  clothing_taxon = taxonomy.taxons.create(:name => 'Clothing', :parent_id => root.id)
  bags_taxon = taxonomy.taxons.create(:name => 'Bags', :parent_id => root.id)
  mugs_taxon = taxonomy.taxons.create(:name => 'Mugs', :parent_id => root.id)

  taxonomy = Taxonomy.find_by_name('Brand')
  root = taxonomy.root
  taxon = taxonomy.taxons.create(:name => "Ruby on Rails", :parent_id => root.id)

  product = Factory(:product, :name => "Ruby on Rails Ringer T-shirt", :price => "17.99")
  product.taxons << taxon
  product.taxons << clothing_taxon

  product = Factory(:product, :name => "Ruby on Rails Mug", :price => "13.99")
  product.taxons << taxon
  product.taxons << mugs_taxon

  product = Factory(:product, :name => "Ruby on Rails Tote", :price => "15.99")
  product.taxons << taxon
  product.taxons << bags_taxon

  product = Factory(:product, :name => "Ruby on Rails Bag", :price => "22.99")
  product.taxons << taxon
  product.taxons << bags_taxon

  product = Factory(:product, :name => "Ruby on Rails Baseball Jersey", :price => "19.99")
  product.taxons << taxon
  product.taxons << clothing_taxon

  product = Factory(:product, :name => "Ruby on Rails Stein", :price => "16.99")
  product.taxons << taxon
  product.taxons << mugs_taxon

  product = Factory(:product, :name => "Ruby on Rails Jr. Spaghetti", :price => "19.99")
  product.taxons << taxon
  product.taxons << clothing_taxon

  taxon = taxonomy.taxons.create(:name => "Ruby", :parent_id => root.id)
  product = Factory(:product, :name => "Ruby Baseball Jersey", :price => "19.99")
  product.taxons << taxon
  product.taxons << clothing_taxon

  taxon = taxonomy.taxons.create(:name => "Apache", :parent_id => root.id)
  product = Factory(:product, :name => "Apache Baseball Jersey", :price => "19.99")
  product.taxons << taxon
  product.taxons << clothing_taxon

end

Then /^verify products listing for top search result$/ do
  page.all('ul.product-listing li').size.should == 1
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby on Rails Ringer T-shirt $17.99"]
end

Then /^verify products listing for Ruby on Rails brand$/ do
  page.all('ul.product-listing li').size.should == 7
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  array = ["Ruby on Rails Bag $22.99",
   "Ruby on Rails Baseball Jersey $19.99",
   "Ruby on Rails Jr. Spaghetti $19.99",
   "Ruby on Rails Mug $13.99",
   "Ruby on Rails Ringer T-shirt $17.99",
   "Ruby on Rails Stein $16.99",
   "Ruby on Rails Tote $15.99"]
  tmp.sort!.should == array
end

Then /^verify products listing for Ruby brand$/ do
  page.all('ul.product-listing li').size.should == 1
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby Baseball Jersey $19.99"]
end

Then /^verify products listing for Apache brand$/ do
  page.all('ul.product-listing li').size.should == 1
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Apache Baseball Jersey $19.99"]
end

Then /^verify products listing for Clothing category$/ do
  page.all('ul.product-listing li').size.should == 5
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Apache Baseball Jersey $19.99",
 "Ruby Baseball Jersey $19.99",
 "Ruby on Rails Baseball Jersey $19.99",
 "Ruby on Rails Jr. Spaghetti $19.99",
 "Ruby on Rails Ringer T-shirt $17.99"]
end

Then /^verify products listing for Bags category$/ do
  page.all('ul.product-listing li').size.should == 2
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby on Rails Bag $22.99", "Ruby on Rails Tote $15.99"]
end

Then /^verify products listing for Mugs category$/ do
  page.all('ul.product-listing li').size.should == 2
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby on Rails Mug $13.99", "Ruby on Rails Stein $16.99"]
end

Then /^verify products listing for price range search 15-18$/ do
  page.all('ul.product-listing li').size.should == 3
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby on Rails Ringer T-shirt $17.99", "Ruby on Rails Stein $16.99", "Ruby on Rails Tote $15.99"]
end

Then /^verify products listing for price range search 18 and above$/ do
  page.all('ul.product-listing li').size.should == 3
  tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
  tmp.delete("")
  tmp.sort!.should == ["Ruby on Rails Bag $22.99",
                       "Ruby on Rails Baseball Jersey $19.99",
                       "Ruby on Rails Jr. Spaghetti $19.99"]
end


Then /^I should get a "(\d+) ([^"]+)" response$/ do |http_status, message|
  #response.status.should == "#{http_status} #{message}"    # webrat
  page.driver.status_code.should == http_status.to_i        # capybara
end

