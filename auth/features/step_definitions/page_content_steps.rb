Then /^I should see "([^\"]*)" translation$/ do |key|
  page.should have_content(I18n.t(key))
end

Then /^I should be signed in$/ do
  page.should have_content("Logout")
end

Then /^I should be signed out$/ do
  page.should have_content("Log In")
end

Then /^I should see error messages$/ do
  page.should have_css("#errorExplanation")
end
