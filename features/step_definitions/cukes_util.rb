#
# Usage :
#
#  Then verify data from "table.index" with following tabular values:
#    | Name  | Action |
#    | Shirt | ignore |
#    | Mug   | ignore |
#    | Bag   | ignore |
#
Then /^verify data from "(.*)" with following tabular values:$/ do |selector, expected_table|
  expected_tableh = expected_table.hashes

  real_table = tableish("#{selector} tr", "td,th")

  expected_tableh.first.keys.sort.should == real_table.first.sort

  expected_table = []
  expected_table << real_table.first
  expected_tableh.each do |h|
    t = []
    real_table.first.each { |key| t << h.fetch(key) }
    expected_table << t
  end

  expected_table.each_with_index do |row, index_i|
    row.each_with_index do |element,index_j|
      unless element == 'ignore'
        element.should == real_table.at(index_i).at(index_j)
      end
    end
  end
end

Then /^verify empty table for selector "(.*)"$/ do |selector|
  tableish("#{selector} tr", "td,th").size.should == 1
end


Then /^I should see row (.*) and column (.*) to have value "(.*)" with selector "(.*)"$/ do |row,col,value,selector|
  output = tableish("#{selector} tr", "td,th")
  row = output.at(row.to_i)
  data = row.at(col.to_i)
  data.should == value
end

Then /^I wait for (.*) seconds?$/ do |seconds|
  sleep seconds.to_i
end

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

When /^I click on first link with class "(.*)"$/ do |class_name|
  page.first('.'+class_name).click
end

When /^I check first element with class "(.*)"$/ do |class_name|
  page.first('.'+class_name).set(true)
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
