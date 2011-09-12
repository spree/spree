Given /^I am a valid API user but not admin$/ do
  @user = Factory(:user)
  authorize @user.authentication_token, "X"
end

Then /^I set "([^"]*)" and PUT request to "([^"]*)"$/ do |data,path|
  puts data
  put path,'{"setting":{"select_taxons_from_tree":true,"orders_per_page":100}}'
end

Then /^response "([^"]*)" should be "([^"]*)"$/ do |set,curr_data|
  page = JSON.load(last_response.body)
  page['data'][set].to_s.should == curr_data
end
