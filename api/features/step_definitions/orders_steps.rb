Given /^I have (\d+) orders$/ do |o|
  user = Factory(:user)
  Order.delete_all
  Order.create(:email => user.email,:number => 100)
  Order.create(:email => user.email,:number => 101)
  Order.create(:email => user.email,:number => 102)
  Order.create(:email => user.email,:number => 103)
  Order.create(:email => user.email,:number => 104)
  @orders = Order.all
end

When /^I send a GET request to "([^"]*)"$/ do |path|
  url = if path == 'first country'
    "/api/countries/#{Country.first.id}"
  else
    path
  end
  get url
end

Then /^the response status should be "([^"]*)"$/ do |status|
  last_response.status.should == status.to_i
end

Then /^the response should be an array with (\d+) orders/ do |num|
  page = JSON.parse(last_response.body)
  page.map { |d| d[name] }.length.should == num.to_i
  page.first.keys.sort.should == ["order"]

  keys = ["adjustment_total", "bill_address_id", "completed_at", "created_at", "credit_total", "email",
    "id", "item_total", "number", "payment_state", "payment_total", "ship_address_id", "shipment_state",
    "shipping_method_id", "special_instructions", "state", "total", "updated_at", "user_id"]

  page.first['order'].keys.sort.should == keys
end

Then /^the response should have country information$/ do
  page = JSON.parse(last_response.body)
  page['country']['name'].should == 'Afghanistan'
  page['country']['iso_name'].should == 'AFGHANISTAN'
  page['country']['iso3'].should == 'AFG'
  page['country']['iso'].should == 'AF'
  page['country']['numcode'].should == 4
end

Then /^the response should be an array with (\d+) countries$/ do |num|
  page = JSON.parse(last_response.body)
  page.map { |d| d[name] }.length.should == num.to_i
  page.first.keys.sort.should == ["country"]

  keys = ["id", "iso", "iso3", "iso_name", "name", "numcode"]
  page.first['country'].keys.sort.should == keys
end
