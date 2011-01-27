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
  get path
end

Then /^the response status should be "([^"]*)"$/ do |status|
  last_response.status.should == status.to_i
end

Then /^the response should be an array with (\d+) "([^"]*)" elements$/ do |num, name|
  page = JSON.parse(last_response.body)
  #puts page.inspect
  page.map { |d| d[name] }.length.should == num.to_i

  page.first.keys.sort.should == ["order"]

  keys = ["adjustment_total", "bill_address_id", "completed_at", "created_at", "credit_total", "email",
    "id", "item_total", "number", "payment_state", "payment_total", "ship_address_id", "shipment_state",
    "shipping_method_id", "special_instructions", "state", "total", "updated_at", "user_id"]

  page.first['order'].keys.sort.should == keys

end
