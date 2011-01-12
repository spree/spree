Given /^I have (\d+) orders$/ do |o|
  user = Fabricate(:user)
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
end
