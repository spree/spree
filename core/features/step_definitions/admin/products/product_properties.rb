When /^I custom fill in "(.*)" with "(.*)"$/ do |selector, value|
  node = page.find(selector)
  node.set(value)
end

Then /^I custom should see value "(.*)" for selector "(.*)"$/ do |value, selector|
  node = page.first(selector)
  node.value.should == value
end
