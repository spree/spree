Given /^existing (.*) records are deleted$/ do |type|
  if type == 'zone'
    Zone.delete_all
  elsif type == 'user'
    User.delete_all
  end
end

When /^I follow "([^"]*)" and click OK$/ do |text|
  page.evaluate_script("window.alert = function(msg) { return true; }")
  page.evaluate_script("window.confirm = function(msg) { return true; }")
  When %{I follow "#{text}"}
end

When /^I click first link from selector "(.*)" and click OK$/ do |selector|
  page.evaluate_script("window.alert = function(msg) { return true; }")
  page.evaluate_script("window.confirm = function(msg) { return true; }")
  page.first(selector).click
end

When /^I confirm a js popup on the next step$/ do
  page.evaluate_script("window.alert = function(msg) { return true; }")
  page.evaluate_script("window.confirm = function(msg) { return true; }")
end

Given /^all (.*) are deleted$/ do |name|
  name.singularize.gsub(' ','_').camelize.classify.constantize.delete_all
end

Then /^click on css "(.*)"$/ do |selector|
  page.first(:css, selector).click
end

Then /^I debug$/ do
  require 'ruby-debug'; debugger
  breakpoint
  0
end

When /^I click first link from selector "(.*)"$/ do |selector|
  page.first(selector).click
end

def page_has_links(table)
  table.hashes.each do |h|
    #selector = h[:within][1..-1]
    #b = page.all(:xpath, "//div[@id='admin-menu']//a")
    #puts b.each {|r| puts r.native }
    #page.should have_xpath( "//div[@id='#{selector}']//a[@href='#{h[:url]}']", :text => h[:text] )
    within(h[:within]) do
      page.find_link(h[:text])[:href].should == h[:url]
    end
  end
end

# Usage:
#
# Then page should have following links:
#  | url                                      | text          | within      |
#  | http://github.com/railsdog/spree         | admin_data    | #footer     |
#  | http://github.com/railsdog/spree/issues  | Report Bug    | #footer     |
#  | http://github.com/railsdog/spree/wiki    | Documentation | #footer     |
#  | /admin                                   | Admin         | #admin-menu |
Then /^page should have following links?:$/ do |table|
  page_has_links(table)
end
