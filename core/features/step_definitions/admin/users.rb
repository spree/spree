Then /^I should see listing users tabular attributes with order (.*)$/ do |order|
  output = tableish('table#listing_users tr', 'td,th')
  data = output[0]
  data[0].should match(/User/)

  data = output[1]
  data[0].should == User.limit(1).order(order).to_a.first.email
end

