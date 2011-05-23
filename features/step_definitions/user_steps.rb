Given /^no user exists with an email of "(.*)"$/ do |email|
  User.find_by_email(email).should be_nil
end

Then /^(\d+) users should exist$/ do |c|
  User.count.should == c.to_i
end

Given /^an anonymous user has been created$/ do
  User.anonymous!
end

