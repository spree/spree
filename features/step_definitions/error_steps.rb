Then /^I should see error messages$/ do
  assert page.has_css?("div.errorExplanation") || page.has_css?("div.errors")
end
