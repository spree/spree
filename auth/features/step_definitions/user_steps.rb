Given /^I am signed up as "(.+)\/(.+)"$/ do |email, password|
  @user = User.create!(
    :email                 => email,
    :password              => password,
    :password_confirmation => password)
end

Given /^I have an admin account of "(.+)\/(.+)"$/ do |email, password|
  @user = User.create!(
    :email                 => email,
    :password              => password,
    :password_confirmation => password)
  @user.roles << Role.find_by_name("admin")
  @user.save
end

When /^I sign in as "(.*)\/(.*)"$/ do |email, password|
  When %{I go to the sign in page"}
  And %{I fill in "Email" with "#{email}"}
  And %{I fill in "Password" with "#{password}"}
  And %{I press "Log In"}
end

Given /^a user exists with an email of "(.*)"$/ do |email|
  user = User.anonymous!
  user.update_attribute("email", email)
end

Given /^no user exists with an email of "(.*)"$/ do |email|
  User.find_by_email(email).should be_nil
end


Then /^I should be logged out$/ do
  page.should have_content("Log In")
end
