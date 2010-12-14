Then /^I should see "([^\"]*)" translation$/ do |key|
  response.should contain(I18n.t(key))
end

Then /^I should be signed in$/ do
  response.should contain("Logout")
end

Then /^I should be signed out$/ do
  response.should contain("Log In")
end

Then /^I should see error messages$/ do
  response.should contain("errors prohibited this record from being saved")
end