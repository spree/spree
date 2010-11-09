Given /^I have (\d+) orders$/ do |o|
  user = Fabricate(:user)
  @orders = Array.new(o.to_i, Fabricate(:order, :user => user))
end

When /^I send a GET request to "([^"]*)"$/ do |path|
  get path
  puts last_request.inspect
  puts last_response.inspect
end

Then /^the response status should be "([^"]*)"$/ do |status|
  last_response.status.should == status.to_i
end

Then /^the response should be an array with (\d+) "([^"]*)" elements$/ do |num, name|
  page = JSON.parse(last_response.body)
  page.map { |d| d[name] }.length.should == num.to_i
end
