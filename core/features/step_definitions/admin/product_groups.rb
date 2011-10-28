Then /^I should see listing product groups tabular attributes$/ do
  output = tableish('table#listing_product_groups tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == 'URL'
  data[2].should == 'Product scopes'
  data[3].should == 'Product count'
  data[4].should == 'Action'

  data = output[1]
  data[0].should == Spree::ProductGroup.limit(1).order('name DESC').to_a.first.name
end

Then /^I should see product groups products listing with (.*) by product name$/ do |direction|
  output = tableish('table.index tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == 'Action'

  data = output[1]
  first_item = data[0]

  data = output[2]
  second_item = data[0]

  if direction == 'ascend'
    first_item.should == 'apache cap'
    second_item.should == 'ruby on rails t-shirt'
  else
    second_item.should == 'apache cap'
    first_item.should == 'ruby on rails t-shirt'
  end

end

Given /^the price of apache cap is 10$/ do
  product = Spree::Product.find_by_name('apache cap')
  master = product.master
  master.price = 10.00
  master.save
end

Given /^the price of rails t-shirt cap is 30 in product group context$/ do
  product = Spree::Product.find_by_name('ruby on rails t-shirt')
  master = product.master
  master.price = 30.00
  master.save
end

Given /^apache cap has 1 line item$/ do
  product = Spree::Product.find_by_name('apache cap')
  master = product.master
  Factory(:line_item, :variant => master)
end

Given /^ruby on rails t-shirt has 2 line items$/ do
  product = Spree::Product.find_by_name('ruby on rails t-shirt')
  master = product.master
  Factory(:line_item, :variant => master)
  Factory(:line_item, :variant => master)
end
