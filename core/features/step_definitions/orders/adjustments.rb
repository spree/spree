When /^I follow "New Adjustment" custom$/ do
  page.first('#content .toolbar .actions li a').click
end

When /^I click first link from selector "(.*)"$/ do |selector|
  page
  require 'ruby-debug'; debugger
  page.first(selector).click
end

Given /^an adjustment exists for order R100$/ do
  order = Order.find_by_number('R100')
  Factory(:adjustment, :order => order)
end
