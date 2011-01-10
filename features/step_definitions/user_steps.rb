Given /^I am signed up as "(.+)\/(.+)"$/ do |email, password|
  Factory(:user, :email => email, :password => password, :password_confirmation => password)
end

Given /^I have an admin account of "(.+)\/(.+)"$/ do |email, password|
  Factory(:admin_user, :email => email, :password => password, :password_confirmation => password)
end

When /^I sign in as "(.*)\/(.*)"$/ do |email, password|
  When %{I go to the sign in page"}
  And %{I fill in "Email" with "#{email}"}
  And %{I fill in "Password" with "#{password}"}
  And %{I press "Log In"}
end

Given /^no user exists with an email of "(.*)"$/ do |email|
  User.find_by_email(email).should be_nil
end

Then /^I should be logged out$/ do
  page.should have_content("Log In")
end

Then /^I should be logged in$/ do
  page.should_not have_content("Log In")
end

Given /^I am logged out$/ do
  begin
    click_link("Logout")
  rescue Capybara::ElementNotFound
  end
end

Then /^(\d+) users should exist$/ do |c|
  User.count.should == c.to_i
end

Then /^I should have (\d+) order$/ do |c|
  User.find_by_email('email@person.com').orders.count.should == c.to_i
end
