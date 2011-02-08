When /^I follow custom admin edit user link$/ do
  user = User.find_by_email('a@example.com')
  page.click_link("admin_edit_user_#{user.id}")
end

Then /^I should see listing users tabular attributes with order (.*)$/ do |order|
  output = tableish('table#listing_users tr', 'td,th')
  data = output[0]
  data[0].should match(/User/)

  data = output[1]
  data[0].should == User.limit(1).order(order).to_a.first.email
end

Then /^I should see listing users tabular attributes for search result case$/ do
  output = tableish('table#listing_users tr', 'td,th')
  output.size.should == 2
  data = output[1]
  data[0].should == 'a@example.com'
end
