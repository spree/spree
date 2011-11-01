Given /^I have (\d+) orders$/ do |o|
  user = Factory(:user)
  Spree::Order.delete_all
  (1..o.to_i).each{ |n| Spree::Order.create(:email => user.email,:number => 99 + n) }
  @orders = Spree::Order.all
end

Given /^2 custom line items exist$/ do
  line_item1 = Factory(:line_item)
  Factory(:line_item, :order => line_item1.order)
end

When /^I send a GET request to "([^"]*)"$/ do |path|
  url = if path == 'first country'
    "/api/countries/#{Spree::Country.first.id}"
  elsif path == 'first inventory unit'
    "/api/inventory_units/#{Spree::InventoryUnit.first.id}"
  elsif path == 'first shipment'
    "/api/shipments/#{Spree::Shipment.first.id}"
  elsif path == 'first order'
    "/api/orders/#{Spree::Order.first.id}"
  elsif path == 'first product'
    "/api/products/#{Spree::Product.first.id}"
  elsif path == 'custom line items'
    line_item = Spree::LineItem.last
    "/api/orders/#{line_item.order.id}/line_items"
  elsif path == 'custom states list'
    state = Spree::State.last
    "/api/countries/#{state.country.id}/states"
  elsif path == 'first state'
    state = Spree::State.first
    "/api/countries/#{state.country.id}/states/#{state.id}"
  elsif path == 'first line item'
    line_item = Spree::LineItem.first
    "/api/orders/#{line_item.order.id}/line_items/#{line_item.id}"
  else
    path
  end
  get url
end

Then /^the response status should be "([^"]*)"$/ do |status|
  last_response.status.should == status.to_i
end

Then /^the response should be an array with (\d+) states/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["state"]

  keys = ["abbr", "country_id", "id", "name"]
  page.first['state'].keys.sort.should == keys
end

Then /^the response should have state information$/ do
  page = JSON.load(last_response.body)
  page['state']['abbr'].should  be_true
  page['state']['name'].should  be_true
end

Then /^the response should be an array with (\d+) shipments/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["shipment"]

  keys = ["address", "cost", "created_at", "id", "inventory_units", "number", "order_id", "shipped_at", "shipping_method", "state", "tracking", "updated_at"]
  page.first['shipment'].keys.sort.should == keys
end

Then /^the response should have shipment information$/ do
  page = JSON.load(last_response.body)
  page['shipment']['address'].should  be_true
  page['shipment']['cost'].should  be_true
  page['shipment']['number'].should  be_true
  page['shipment']['shipping_method'].should  be_true
  page['shipment']['state'].should  be_true
  page['shipment']['tracking'].should  be_true
end


Then /^the response should be an array with (\d+) products?/ do |num|
  page = JSON.load(last_response.body)

  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["product"]

  keys = ["available_on", "count_on_hand", "created_at", "deleted_at", "description", "id", "meta_description", "meta_keywords", "name", "permalink", "shipping_category_id", "tax_category_id", "updated_at"]
  page.first['product'].keys.sort.should == keys
end

Then /^the response should have product information$/ do
  page = JSON.load(last_response.body)
  page['product']['permalink'].should  be_true
  page['product']['name'].should  be_true
  page['product']['count_on_hand'].should  be_true
end

Then /^the response should have product information for shirt$/ do
  page = JSON.load(last_response.body).first
  page['product']['permalink'].should  be_true
  page['product']['name'].should  == 'zomg shirt'
  page['product']['count_on_hand'].should  be_true
end

Then /^the response should be an array with (\d+) orders/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["order"]

  keys = ["adjustment_total", "bill_address_id", "completed_at", "created_at", "credit_total", "email",
    "id", "item_total", "number", "payment_state", "payment_total", "ship_address_id", "shipment_state",
    "shipping_method_id", "special_instructions", "state", "total", "updated_at", "user_id"]

  page.first['order'].keys.sort.should == keys
end

Then /^the response should have order information$/ do
  page = JSON.load(last_response.body)
  page['order']['number'].should  be_true
  page['order']['state'].should  be_true
  page['order']['email'].should  be_true
  page['order']['credit_total'].should  be_true
end

Then /^the response should have country information$/ do
  page = JSON.load(last_response.body)
  page['country']['name'].should == 'Afghanistan'
  page['country']['iso_name'].should == 'AFGHANISTAN'
  page['country']['iso3'].should == 'AFG'
  page['country']['iso'].should == 'AF'
  page['country']['numcode'].should == 4
end

Then /^the response should be an array with (\d+) countries$/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["country"]

  keys = ["id", "iso", "iso3", "iso_name", "name", "numcode"]
  page.first['country'].keys.sort.should == keys
end

Then /^the response should be an array with (\d+) inventory units$/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["inventory_unit"]

  keys = ["created_at", "id", "lock_version", "order_id", "return_authorization_id", "shipment_id", "state", "updated_at", "variant_id"]
  page.first['inventory_unit'].keys.sort.should == keys
end

Then /^the response should have inventory unit information$/ do
  page = JSON.load(last_response.body)
  page['inventory_unit']['lock_version'].should be_true
  page['inventory_unit']['state'].should be_true
end

Then /^the response should be an array with (\d+) line items$/ do |num|
  page = JSON.load(last_response.body)
  page.map { |d| d['name'] }.length.should == num.to_i
  page.first.keys.sort.should == ["line_item"]

  keys =  ["created_at", "description", "id", "order_id", "price", "quantity", "updated_at", "variant", "variant_id"]
  page.first['line_item'].keys.sort.should == keys
end

Then /^the response should have line item information$/ do
  page = JSON.load(last_response.body)
  page['line_item']['description'].should match(/Size: S/)
  page['line_item']['price'].should  be_true
  page['line_item']['quantity'].should be_true
end
