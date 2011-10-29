Given /^no user exists with an email of "(.*)"$/ do |email|
  Spree::User.find_by_email(email).should be_nil
end

Then /^(\d+) users should exist$/ do |c|
  Spree::User.count.should == c.to_i
end

Given /^an anonymous user has been created$/ do
  Spree::User.anonymous!
end

